import Foundation
import Speech
import AVFoundation

// MARK: - Reconnaissance vocale (Speech-to-Text)

/// Gère la reconnaissance vocale hors ligne avec le framework Speech d'Apple
final class SpeechRecognizer: NSObject, ObservableObject {

    static let shared = SpeechRecognizer()

    private var speechRecognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isAvailable: Bool = false
    @Published var transcribedText: String = ""

    private override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    /// Démarre l'écoute
    func start(onUpdate: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        // Demander l'autorisation
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }

            DispatchQueue.main.async {
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.request = SFSpeechAudioBufferRecognitionRequest()
                self.request?.shouldReportPartialResults = true

                self.task = recognizer.recognitionTask(with: self.request!) { result, error in
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        DispatchQueue.main.async {
                            self.transcribedText = text
                            onUpdate(text)
                        }
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        self.audioEngine.stop()
                        self.audioEngine.inputNode.removeTap(onBus: 0)
                        self.request = nil
                        self.task = nil
                    }
                }

                let inputNode = self.audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    self.request?.append(buffer)
                }

                self.audioEngine.prepare()
                try? self.audioEngine.start()
            }
        }
    }

    /// Arrête l'écoute et retourne le texte final
    func stop(completion: @escaping (String?) -> Void) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        completion(transcribedText)
        transcribedText = ""
    }
}

// MARK: - Synthèse vocale (Text-to-Speech)

/// Gère la synthèse vocale hors ligne avec AVSpeechSynthesizer
final class SpeechSynthesizer: NSObject, ObservableObject {

    static let shared = SpeechSynthesizer()

    private let synthesizer = AVSpeechSynthesizer()

    @Published var isSpeaking = false

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Lit un texte à voix haute en français
    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        // Arrêter la lecture en cours
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension SpeechSynthesizer: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
