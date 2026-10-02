import Foundation

// MARK: - Rôle des messages

enum MessageRole: String, Codable, CaseIterable {
    case system
    case user
    case assistant

    var displayName: String {
        switch self {
        case .system: return "Système"
        case .user: return "Vous"
        case .assistant: return "Agent"
        }
    }
}

// MARK: - Message de chat

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var tokensPerSecond: Double?

    init(role: MessageRole, content: String, tokensPerSecond: Double? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.tokensPerSecond = tokensPerSecond
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, tokensPerSecond
    }
}

// MARK: - Conversation persistante

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var modelId: String?

    init(title: String = "Nouvelle conversation") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelId = nil
    }
}

// MARK: - Localisation d'un modèle installé

enum ModelLocation: Equatable {
    case bundled(URL)      // Préinstallé dans le bundle de l'app
    case documents(URL)     // Téléchargé dans Documents
    case remote             // Pas encore installé
}

// MARK: - Modèle installé

struct InstalledModel: Identifiable {
    let id: String
    let info: ModelInfo
    let location: ModelLocation

    var isAvailableOffline: Bool {
        if case .remote = location { return false }
        return true
    }

    var badge: String {
        switch location {
        case .bundled: return "Inclus"
        case .documents: return "Installé"
        case .remote: return "À télécharger"
        }
    }

    var badgeColor: String {
        switch location {
        case .bundled: return "green"
        case .documents: return "blue"
        case .remote: return "gray"
        }
    }
}

// MARK: - Modèle GGUF téléchargeable / préinstallable

struct ModelInfo: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let sizeLabel: String
    let url: String
    let description: String
    let recommendedRAM: Int
    let contextLength: Int
    let isChatML: Bool
    let bundleFileName: String?        // Nom du fichier si préinstallé dans le bundle
    let preinstallRecommended: Bool     // True = à préinstaller par défaut

    var fileSizeBytes: Int64? {
        switch id {
        case "qwen3-0.6b": return 440_000_000
        case "qwen3-4b": return 2_500_000_000
        case "gemma3-1b": return 750_000_000
        case "llama3.2-3b": return 2_100_000_000
        default: return nil
        }
    }

    /// Modèles recommandés (ChatML natif)
    static let recommended: [ModelInfo] = [
        ModelInfo(
            id: "qwen3-0.6b",
            name: "Qwen 3 0.6B",
            sizeLabel: "~440 MB",
            url: "https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf",
            description: "Ultra-léger et rapide. Idéal pour tous les iPhone à partir de l'iPhone 12.",
            recommendedRAM: 4,
            contextLength: 4096,
            isChatML: true,
            bundleFileName: "Qwen_Qwen3-0.6B-Q4_K_M.gguf",
            preinstallRecommended: true
        ),
        ModelInfo(
            id: "qwen3-4b",
            name: "Qwen 3 4B",
            sizeLabel: "~2.5 GB",
            url: "https://huggingface.co/bartowski/Qwen_Qwen3-4B-GGUF/resolve/main/Qwen_Qwen3-4B-Q4_K_M.gguf",
            description: "Meilleure qualité de raisonnement. Recommandé pour iPhone 15 Pro et plus.",
            recommendedRAM: 8,
            contextLength: 4096,
            isChatML: true,
            bundleFileName: "Qwen_Qwen3-4B-Q4_K_M.gguf",
            preinstallRecommended: false
        )
    ]

    /// Modèles avancés
    static let advanced: [ModelInfo] = [
        ModelInfo(
            id: "gemma3-1b",
            name: "Gemma 3 1B",
            sizeLabel: "~750 MB",
            url: "https://huggingface.co/lmstudio-community/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf",
            description: "Bon équilibre. Template Google — utilise llama_chat_apply_template.",
            recommendedRAM: 4,
            contextLength: 2048,
            isChatML: false,
            bundleFileName: nil,
            preinstallRecommended: false
        ),
        ModelInfo(
            id: "llama3.2-3b",
            name: "Llama 3.2 3B",
            sizeLabel: "~2.1 GB",
            url: "https://huggingface.co/lmstudio-community/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            description: "Modèle Meta. Template Llama 3 — utilise llama_chat_apply_template.",
            recommendedRAM: 8,
            contextLength: 4096,
            isChatML: false,
            bundleFileName: nil,
            preinstallRecommended: false
        )
    ]

    static let all: [ModelInfo] = recommended + advanced
}

// MARK: - Presets de génération

enum GenerationPreset: String, CaseIterable, Codable {
    case rapide
    case equilibre
    case creatif

    var displayName: String {
        switch self {
        case .rapide: return "Rapide"
        case .equilibre: return "Équilibré"
        case .creatif: return "Créatif"
        }
    }

    var icon: String {
        switch self {
        case .rapide: return "bolt.fill"
        case .equilibre: return "scalemass.fill"
        case .creatif: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .rapide: return "Réponses courtes et rapides"
        case .equilibre: return "Bon équilibre qualité/vitesse"
        case .creatif: return "Plus de créativité, réponses longues"
        }
    }

    var temperature: Float {
        switch self {
        case .rapide: return 0.3
        case .equilibre: return 0.7
        case .creatif: return 1.1
        }
    }

    var topP: Float {
        switch self {
        case .rapide: return 0.8
        case .equilibre: return 0.9
        case .creatif: return 0.95
        }
    }

    var maxTokens: Int {
        switch self {
        case .rapide: return 256
        case .equilibre: return 512
        case .creatif: return 1024
        }
    }
}

// MARK: - Personnalités préconfigurées

enum Persona: String, CaseIterable, Codable {
    case assistant
    case traducteur
    case redacteur
    case codeur
    case tuteur

    var displayName: String {
        switch self {
        case .assistant: return "Assistant"
        case .traducteur: return "Traducteur"
        case .redacteur: return "Rédacteur"
        case .codeur: return "Codeur"
        case .tuteur: return "Tuteur"
        }
    }

    var icon: String {
        switch self {
        case .assistant: return "brain.head.profile"
        case .traducteur: return "globe"
        case .redacteur: return "pencil.line"
        case .codeur: return "chevron.left.forwardslash.chevron.right"
        case .tuteur: return "graduationcap.fill"
        }
    }

    var systemPrompt: String {
        switch self {
        case .assistant:
            return """
            Tu es un assistant IA local fonctionnant entièrement sur l'iPhone de l'utilisateur.
            Tu es privé, sécurisé, et aucune donnée ne quitte l'appareil.
            Réponds en français de manière claire et concise.
            """
        case .traducteur:
            return """
            Tu es un traducteur expert. L'utilisateur peut écrire dans n'importe quelle langue.
            Si le message est en français, traduis-le en anglais.
            Si le message est dans une autre langue, traduis-le en français.
            Ne donne que la traduction, sans explication.
            """
        case .redacteur:
            return """
            Tu es un rédacteur professionnel. Aide l'utilisateur à améliorer ses textes:
            correction, reformulation, résumé, ou création de contenu.
            Propose des alternatives élégantes et naturelles en français.
            """
        case .codeur:
            return """
            Tu es un expert en programmation. Aide l'utilisateur avec du code:
            explications, exemples, debug, optimisation.
            Réponds en français mais le code reste en anglais.
            Utilise des blocs markdown avec coloration syntaxique.
            """
        case .tuteur:
            return """
            Tu es un tuteur pédagogue. Explique les concepts simplement, avec des exemples concrets.
            Pose des questions pour vérifier la compréhension.
            Adapte ton niveau de langage au sujet demandé. Réponds en français.
            """
        }
    }
}

// MARK: - Erreurs

enum LlamaError: LocalizedError {
    case modelLoadFailed(String)
    case contextCreationFailed
    case tokenizationFailed
    case generationFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path): return "Impossible de charger le modèle: \(path)"
        case .contextCreationFailed: return "Impossible de créer le contexte d'inférence"
        case .tokenizationFailed: return "Échec de la tokenisation"
        case .generationFailed(let msg): return "Erreur de génération: \(msg)"
        case .downloadFailed(let msg): return "Échec du téléchargement: \(msg)"
        }
    }
}
