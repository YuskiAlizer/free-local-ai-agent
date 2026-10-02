import Foundation

/// Gère la persistance des conversations en JSON local
@MainActor
final class ConversationStore: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published var currentConversationId: UUID?

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("conversations.json")
        loadConversations()
    }

    var currentConversation: Conversation? {
        guard let id = currentConversationId else { return nil }
        return conversations.first(where: { $0.id == id })
    }

    func createNewConversation(title: String = "Nouvelle conversation") -> UUID {
        let conv = Conversation(title: title)
        conversations.insert(conv, at: 0)
        currentConversationId = conv.id
        saveConversations()
        return conv.id
    }

    func deleteConversation(id: UUID) {
        conversations.removeAll(where: { $0.id == id })
        if currentConversationId == id {
            currentConversationId = conversations.first?.id
        }
        saveConversations()
    }

    func appendMessage(_ message: ChatMessage, to conversationId: UUID) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[idx].messages.append(message)
        conversations[idx].updatedAt = Date()

        // Auto-titre depuis le premier message utilisateur
        if conversations[idx].title == "Nouvelle conversation",
           message.role == .user {
            let title = String(message.content.prefix(40))
            conversations[idx].title = title.isEmpty ? "Nouvelle conversation" : title
        }
        saveConversations()
    }

    func updateLastAssistantMessage(content: String, tps: Double?, conversationId: UUID) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        if let lastIdx = conversations[idx].messages.lastIndex(where: { $0.role == .assistant }) {
            conversations[idx].messages[lastIdx].content = content
            conversations[idx].messages[lastIdx].tokensPerSecond = tps
            conversations[idx].updatedAt = Date()
        }
        saveConversations()
    }

    func switchTo(_ id: UUID) {
        currentConversationId = id
    }

    func clearAll() {
        conversations = []
        currentConversationId = nil
        saveConversations()
    }

    // MARK: - Persistance

    private func loadConversations() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Conversation].self, from: data) else {
            return
        }
        conversations = decoded
        currentConversationId = conversations.first?.id
    }

    private func saveConversations() {
        guard let encoded = try? JSONEncoder().encode(conversations) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
