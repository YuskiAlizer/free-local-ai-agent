import Foundation

/// Gère le téléchargement de modèles GGUF avec progression
@MainActor
final class DownloadManager: ObservableObject {

    @Published var downloads: [String: DownloadState] = [:]

    struct DownloadState: Identifiable {
        let id: String
        var progress: Double
        var totalBytes: Int64
        var downloadedBytes: Int64
        var isCompleted: Bool
        var error: String?
    }

    /// Télécharge un modèle avec progression réelle via URLSession delegate
    func download(model: ModelInfo) async throws -> URL {
        let destDir = LlamaEngine.getModelDirectory()
        let destURL = destDir.appendingPathComponent("\(model.id).gguf")

        // Déjà téléchargé ?
        if FileManager.default.fileExists(atPath: destURL.path) {
            return destURL
        }

        guard let url = URL(string: model.url) else {
            throw LlamaError.downloadFailed("URL invalide")
        }

        // Initialiser l'état
        downloads[model.id] = DownloadState(
            id: model.id,
            progress: 0,
            totalBytes: model.fileSizeBytes ?? 0,
            downloadedBytes: 0,
            isCompleted: false,
            error: nil
        )

        // Téléchargement avec progression
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            downloads[model.id]?.error = "Erreur serveur"
            throw LlamaError.downloadFailed("Erreur serveur")
        }

        // Déplacer le fichier temporaire vers la destination
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        downloads[model.id]?.isCompleted = true
        downloads[model.id]?.progress = 1.0

        return destURL
    }

    /// État d'un téléchargement
    func state(for modelId: String) -> DownloadState? {
        downloads[modelId]
    }
}
