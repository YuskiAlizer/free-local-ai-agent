import Foundation
import Combine
import UIKit

/// ViewModel principal — coordonne l'engine, les téléchargements, et la persistance
@MainActor
final class ChatViewModel: ObservableObject {

    // État de l'UI
    @Published var isLoadingModel = false
    @Published var isGenerating = false
    @Published var loadProgress: Double = 0
    @Published var loadStatus: String = ""
    @Published var errorMessage: String?
    @Published var tokensPerSecond: Double = 0
    @Published var currentPartialResponse = ""
    @Published var currentModelInfo: ModelInfo?
    @Published var persona: Persona = .assistant
    @Published var preset: GenerationPreset = .equilibre
    @Published var shouldStop = false
    @Published var showModelSheet = false
    @Published var installedModels: [InstalledModel] = []
    private var generationTask: Task<Void, Never>?

    // Services
    let engine = LlamaEngine()
    let downloadManager = DownloadManager()
    let store = ConversationStore()

    var isModelLoaded: Bool { engine.isLoaded }

    // MARK: - Détection de l'appareil

    var deviceRAM: Int {
        let mem = ProcessInfo.processInfo.physicalMemory
        let ramGB = Int(mem / (1024 * 1024 * 1024))
        if ramGB <= 3 { return 4 }
        if ramGB <= 5 { return 6 }
        if ramGB <= 7 { return 8 }
        return ramGB
    }

    var deviceModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.compactMap { element in
            guard let value = element.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(value)))
        }.joined()
    }

    var recommendedModel: ModelInfo {
        if deviceRAM >= 8 {
            return ModelInfo.recommended.first(where: { $0.id == "qwen3-4b" })
                ?? ModelInfo.recommended[0]
        }
        return ModelInfo.recommended[0]
    }

    // MARK: - Détection des modèles installés

    /// Met à jour la liste des modèles installés (bundle + documents)
    func refreshInstalledModels() {
        installedModels = LlamaEngine.listInstalledModels()
    }

    /// Vérifie si le modèle recommandé est déjà disponible localement
    var recommendedModelLocation: ModelLocation {
        LlamaEngine.isModelAvailable(recommendedModel)
    }

    /// True si au moins un modèle est préinstallé dans le bundle
    var hasBundledModel: Bool {
        !LlamaEngine.listBundledModels().isEmpty
    }

    // MARK: - Démarrage automatique (1 tap)

    /// Démarre immédiatement avec le meilleur modèle disponible.
    /// Priorité: bundle > documents > téléchargement
    func quickStart() async {
        let model = recommendedModel
        let location = LlamaEngine.isModelAvailable(model)

        switch location {
        case .bundled(let url):
            // Modèle préinstallé — chargement immédiat
            loadStatus = "Chargement du modèle inclus..."
            loadExistingModel(at: url, info: model)
        case .documents(let url):
            // Modèle déjà téléchargé — chargement immédiat
            loadStatus = "Chargement du modèle..."
            loadExistingModel(at: url, info: model)
        case .remote:
            // Pas disponible — téléchargement
            await downloadAndLoad(model: model)
        }
    }

    // MARK: - Téléchargement + Chargement

    func downloadAndLoad(model: ModelInfo) async {
        errorMessage = nil
        isLoadingModel = true

        loadStatus = model.id
        do {
            let url = try await downloadManager.download(model: model)
            loadStatus = "Chargement du modèle..."
            loadProgress = 0.5
            let engine = self.engine
            try await Task.detached(priority: .userInitiated) {
                try engine.loadModel(at: url.path, info: model)
            }.value
            currentModelInfo = model
            loadStatus = "Prêt"
            loadProgress = 1.0
            refreshInstalledModels()
        } catch {
            errorMessage = error.localizedDescription
            loadStatus = ""
        }
        isLoadingModel = false
    }

    // MARK: - Chargement d'un modèle existant

    func loadExistingModel(at url: URL, info: ModelInfo) {
        isLoadingModel = true
        loadStatus = "Chargement..."

        let engine = self.engine

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    engine.params.contextLength = UInt32(info.contextLength)
                    engine.params.nGpuLayers = 99
                    try engine.loadModel(at: url.path, info: info)
                }.value
                await MainActor.run {
                    self.currentModelInfo = info
                    self.loadStatus = "Prêt"
                    self.isLoadingModel = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.loadStatus = ""
                    self.isLoadingModel = false
                }
            }
        }
    }

    func unloadModel() {
        engine.unloadModel()
        currentModelInfo = nil
        loadProgress = 0
        loadStatus = ""
    }

    // MARK: - Génération

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              engine.isLoaded else { return }

        if store.currentConversationId == nil {
            _ = store.createNewConversation()
        }
        guard let convId = store.currentConversationId else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        store.appendMessage(userMessage, to: convId)

        engine.params.temperature = preset.temperature
        engine.params.topP = preset.topP
        engine.params.maxTokens = preset.maxTokens
        engine.rebuildSampler()

        shouldStop = false
        isGenerating = true
        currentPartialResponse = ""
        tokensPerSecond = 0

        let engine = self.engine
        let systemPrompt = persona.systemPrompt
        let messages = store.currentConversation?.messages ?? []
        let convId = convId

        generationTask = Task.detached { [weak self] in
            guard let self = self else { return }

            var fullResponse = ""

            do {
                let tps = try engine.generate(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    onToken: { token in
                        fullResponse += token
                        Task { @MainActor in
                            self.currentPartialResponse = fullResponse
                        }
                    },
                    shouldStop: { Task.isCancelled }
                )

                await MainActor.run {
                    self.tokensPerSecond = tps
                    let assistantMessage = ChatMessage(
                        role: .assistant,
                        content: fullResponse,
                        tokensPerSecond: tps
                    )
                    self.store.appendMessage(assistantMessage, to: convId)
                    self.currentPartialResponse = ""
                    self.isGenerating = false
                    self.generationTask = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                    self.generationTask = nil
                }
            }
        }
    }

    func stopGeneration() {
        generationTask?.cancel()
        shouldStop = true
    }
}
