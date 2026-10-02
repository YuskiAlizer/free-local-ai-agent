import Foundation
import llama
import Darwin

/// Moteur d'inférence llama.cpp — isolé de l'UI pour éviter les blocages
/// Toutes les opérations sur pointeurs C se font de manière synchrone dans ce type
final class LlamaEngine: @unchecked Sendable {

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    private var modelPath: String?
    private var loadedModelInfo: ModelInfo?

    /// Paramètres configurables
    struct Params {
        var contextLength: UInt32 = 4096
        var temperature: Float = 0.7
        var topP: Float = 0.9
        var topK: Int32 = 40
        var maxTokens: Int = 512
        var nGpuLayers: Int32 = 99
        var nThreads: Int32 = 0  // 0 = auto
    }

    var params = Params()
    var isLoaded: Bool { model != nil && context != nil }
    var currentModel: ModelInfo? { loadedModelInfo }

    // MARK: - Chargement / Déchargement

    func loadModel(at path: String, info: ModelInfo) throws {
        unloadModel()
        loadedModelInfo = info

        // Paramètres du modèle — décharger toutes les couches sur Metal
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = params.nGpuLayers

        guard let mdl = llama_model_load_from_file(path, modelParams) else {
            throw LlamaError.modelLoadFailed(path)
        }
        model = mdl
        modelPath = path

        // Paramètres du contexte — optimisations performance
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = params.contextLength
        ctxParams.n_batch = 512
        ctxParams.n_ubatch = 512
        ctxParams.n_seq_max = 1
        let nThreads = params.nThreads > 0
            ? params.nThreads
            : Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
        ctxParams.n_threads = nThreads
        ctxParams.n_threads_batch = nThreads
        // Flash Attention pour accélérer l'attention sur Metal
        ctxParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED
        // Offload KQV vers le GPU
        ctxParams.offload_kqv = true
        // Type de cache KV — Q8_0 pour réduire la mémoire sans trop perdre en qualité
        ctxParams.type_k = GGML_TYPE_Q8_0
        ctxParams.type_v = GGML_TYPE_Q8_0

        guard let ctx = llama_init_from_model(mdl, ctxParams) else {
            llama_model_free(mdl)
            model = nil
            throw LlamaError.contextCreationFailed
        }
        context = ctx

        // Créer la chaîne de sampler
        rebuildSampler()
    }

    func unloadModel() {
        if let s = sampler {
            llama_sampler_free(s)
            sampler = nil
        }
        if let ctx = context {
            llama_free(ctx)
            context = nil
        }
        if let mdl = model {
            llama_model_free(mdl)
            model = nil
        }
        modelPath = nil
        loadedModelInfo = nil
    }

    /// Reconstruit le sampler avec les paramètres actuels (utile si température change)
    func rebuildSampler() {
        if let s = sampler {
            llama_sampler_free(s)
        }
        let chainParams = llama_sampler_chain_default_params()
        sampler = llama_sampler_chain_init(chainParams)
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(params.topK))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(params.topP, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(params.temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
    }

    // MARK: - Inférence (callback streaming)

    /// Génère une réponse. `onToken` est appelé pour chaque token généré.
    /// `shouldStop` est vérifié avant chaque token — retourner `true` pour annuler.
    func generate(
        messages: [ChatMessage],
        systemPrompt: String,
        onToken: (String) -> Void,
        shouldStop: () -> Bool
    ) throws -> Double {
        guard let ctx = context, let mdl = model, let smp = sampler else {
            throw LlamaError.contextCreationFailed
        }

        // Réinitialiser la mémoire KV et le sampler
        let mem = llama_get_memory(ctx)
        llama_memory_clear(mem, true)
        llama_sampler_reset(smp)

        // Construire le prompt avec le template du modèle
        let prompt = buildPrompt(messages: messages, systemPrompt: systemPrompt)

        // Tokeniser
        let promptTokens = tokenize(prompt, model: mdl)
        guard !promptTokens.isEmpty else {
            throw LlamaError.tokenizationFailed
        }

        // Batch pour traiter le prompt
        var batch = llama_batch_init(Int32(promptTokens.count), 0, 1)
        for (i, token) in promptTokens.enumerated() {
            batchAdd(&batch, token: token, pos: Int32(i), seqId: 0,
                     logits: i == promptTokens.count - 1)
        }

        // Décoder le prompt
        if llama_decode(ctx, batch) < 0 {
            llama_batch_free(batch)
            throw LlamaError.generationFailed("échec du décodage du prompt")
        }
        llama_batch_free(batch)

        // Génération token par token
        let startTime = Date()
        var tokenCount = 0

        for _ in 0..<params.maxTokens {
            if shouldStop() { break }

            let token = llama_sampler_sample(smp, ctx, -1)

            let vocab = llama_model_get_vocab(mdl)
            if llama_vocab_is_eog(vocab, token) {
                break
            }
            llama_sampler_accept(smp, token)

            let piece = decodeToken(token, model: mdl)
            onToken(piece)

            // Préparer le batch pour le token suivant
            var nextToken = token
            var nextBatch = llama_batch_get_one(&nextToken, 1)
            if llama_decode(ctx, nextBatch) < 0 {
                break
            }

            tokenCount += 1
        }

        let elapsed = Date().timeIntervalSince(startTime)
        return tokenCount > 0 ? Double(tokenCount) / max(elapsed, 0.001) : 0
    }

    // MARK: - Helpers privés

    /// Construit le prompt en utilisant llama_chat_apply_template (template du GGUF)
    /// avec fallback ChatML
    private func buildPrompt(messages: [ChatMessage], systemPrompt: String) -> String {
        // Préparer les messages pour le template
        var swiftMessages: [(role: String, content: String)] = []
        var systemAdded = false

        if !systemPrompt.isEmpty {
            swiftMessages.append((role: "system", content: systemPrompt))
            systemAdded = true
        }

        let historyMessages = systemAdded
            ? messages.filter { $0.role != .system }
            : messages

        for msg in historyMessages {
            swiftMessages.append((role: msg.role.rawValue, content: msg.content))
        }

        // Wrapper pour gérer les C strings correctement
        return withCChatMessages(swiftMessages) { ptr, count in
            // Premier appel: déterminer la taille nécessaire
            let needed = llama_chat_apply_template(nil, ptr, count, true, nil, 0)

            if needed > 0 {
                var buffer = [CChar](repeating: 0, count: Int(needed) + 1)
                let written = buffer.withUnsafeMutableBufferPointer { out in
                    llama_chat_apply_template(nil, ptr, count, true, out.baseAddress, Int32(out.count))
                }
                if written > 0 {
                    return String(cString: buffer)
                }
            }

            // Fallback: ChatML manuel
            return self.buildChatMLPrompt(messages: messages, systemPrompt: systemPrompt)
        }
    }

    /// Crée des C strings stables pour llama_chat_message et appelle body
    private func withCChatMessages<T>(
        _ messages: [(role: String, content: String)],
        _ body: (UnsafePointer<llama_chat_message>, Int) -> T
    ) -> T {
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        var cMessages: [llama_chat_message] = []

        for msg in messages {
            let rolePtr = strdup(msg.role)!
            let contentPtr = strdup(msg.content)!
            cStrings.append(rolePtr)
            cStrings.append(contentPtr)
            cMessages.append(llama_chat_message(
                role: UnsafePointer(rolePtr),
                content: UnsafePointer(contentPtr)
            ))
        }

        defer {
            for ptr in cStrings {
                free(ptr)
            }
        }

        return cMessages.withUnsafeBufferPointer { buffer in
            body(buffer.baseAddress!, cMessages.count)
        }
    }

    /// Fallback ChatML si llama_chat_apply_template échoue
    private func buildChatMLPrompt(messages: [ChatMessage], systemPrompt: String) -> String {
        var prompt = ""
        if !systemPrompt.isEmpty {
            prompt += "<|im_start|>system\n\(systemPrompt)<|im_end|>\n"
        }
        for msg in messages where msg.role != .system {
            prompt += "<|im_start|>\(msg.role.rawValue)\n\(msg.content)<|im_end|>\n"
        }
        prompt += "<|im_start|>assistant\n"
        return prompt
    }

    /// Remplit un llama_batch manuellement
    private func batchAdd(
        _ batch: inout llama_batch,
        token: llama_token,
        pos: llama_pos,
        seqId: Int32,
        logits: Bool
    ) {
        let idx = Int(batch.n_tokens)
        batch.token[idx] = token
        batch.pos[idx] = pos
        batch.n_seq_id[idx] = 1
        batch.seq_id[idx]![0] = seqId
        batch.logits![idx] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    /// Tokenise un texte
    private func tokenize(_ text: String, model: OpaquePointer) -> [llama_token] {
        let vocab = llama_model_get_vocab(model)
        let maxTokens = Int32(text.utf8.count + 16)
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))

        let count = llama_tokenize(
            vocab,
            text,
            Int32(text.utf8.count),
            &tokens,
            maxTokens,
            true,
            false
        )
        return count > 0 ? Array(tokens.prefix(Int(count))) : []
    }

    /// Décode un token en texte
    private func decodeToken(_ token: llama_token, model: OpaquePointer) -> String {
        let vocab = llama_model_get_vocab(model)
        var buf = [CChar](repeating: 0, count: 128)
        let len = llama_token_to_piece(vocab, token, &buf, 128, 0, true)
        if len <= 0 { return "" }
        return String(cString: Array(buf.prefix(Int(len))) + [0])
    }

    deinit { unloadModel() }

    // MARK: - Gestion des fichiers

    /// Répertoire de stockage des modèles GGUF
    static func getModelDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docs.appendingPathComponent("models", isDirectory: true)
        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        return modelsDir
    }

    /// Liste les modèles GGUF déjà téléchargés
    static func listDownloadedModels() -> [URL] {
        let dir = getModelDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "gguf" }
    }

    // MARK: - Modèles préinstallés dans le bundle

    /// Cherche un modèle GGUF dans le bundle de l'app (dossier BundledModels)
    static func bundledModelURL(for model: ModelInfo) -> URL? {
        guard let fileName = model.bundleFileName else { return nil }
        let name = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        // Cherche dans le sous-dossier BundledModels
        if let url = Bundle.main.url(forResource: name, withExtension: "gguf", subdirectory: "BundledModels") {
            return url
        }
        // Cherche à la racine du bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "gguf") {
            return url
        }
        return nil
    }

    /// Liste tous les modèles GGUF embarqués dans le bundle
    static func listBundledModels() -> [URL] {
        var urls: [URL] = []
        // Cherche dans le sous-dossier BundledModels
        if let bundledURLs = Bundle.main.urls(forResourcesWithExtension: "gguf", subdirectory: "BundledModels") {
            urls.append(contentsOf: bundledURLs)
        }
        // Cherche à la racine
        if let rootURLs = Bundle.main.urls(forResourcesWithExtension: "gguf", subdirectory: nil) {
            urls.append(contentsOf: rootURLs)
        }
        return urls
    }

    /// Retourne la liste complète des modèles installés (bundle + documents)
    static func listInstalledModels() -> [InstalledModel] {
        var installed: [InstalledModel] = []

        // Modèles du bundle (préinstallés)
        for model in ModelInfo.all {
            if let bundledURL = bundledModelURL(for: model) {
                installed.append(InstalledModel(
                    id: model.id,
                    info: model,
                    location: .bundled(bundledURL)
                ))
            }
        }

        // Modèles dans Documents (téléchargés)
        for model in ModelInfo.all {
            // Skip si déjà trouvé dans le bundle
            if installed.contains(where: { $0.id == model.id }) { continue }
            let docURL = getModelDirectory().appendingPathComponent("\(model.id).gguf")
            if FileManager.default.fileExists(atPath: docURL.path) {
                installed.append(InstalledModel(
                    id: model.id,
                    info: model,
                    location: .documents(docURL)
                ))
            }
        }

        // Modèles GGUF génériques dans Documents (non reconnus)
        for url in listDownloadedModels() {
            let name = url.deletingPathExtension().lastPathComponent
            if !installed.contains(where: { $0.info.id == name }) {
                let info = ModelInfo.all.first(where: { url.lastPathComponent.contains($0.id) })
                    ?? ModelInfo.recommended[0]
                installed.append(InstalledModel(
                    id: name,
                    info: info,
                    location: .documents(url)
                ))
            }
        }

        return installed
    }

    /// Vérifie si un modèle est déjà disponible (bundle ou documents)
    static func isModelAvailable(_ model: ModelInfo) -> ModelLocation {
        if let bundledURL = bundledModelURL(for: model) {
            return .bundled(bundledURL)
        }
        let docURL = getModelDirectory().appendingPathComponent("\(model.id).gguf")
        if FileManager.default.fileExists(atPath: docURL.path) {
            return .documents(docURL)
        }
        return .remote
    }
}
