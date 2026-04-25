import Foundation
import WhisperKit

// Same model the Python backend used: distil-whisper-large-v3.
// WhisperKit hosts it as `distil-whisper_distil-large-v3` in argmaxinc/whisperkit-coreml.
private let modelVariant = "distil-whisper_distil-large-v3"
private let modelRepo = "argmaxinc/whisperkit-coreml"

actor Transcriber {
    static let shared = Transcriber()

    private var pipeline: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    func transcribe(fileURL: URL) async throws -> String {
        let kit = try await ensureLoaded()
        let results = try await kit.transcribe(audioPath: fileURL.path)
        let text = results.map { $0.text }.joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Kick off model load eagerly so the first ⌥W doesn't block on a 1.5 GB download.
    func preload() {
        Task { _ = try? await ensureLoaded() }
    }

    private func ensureLoaded() async throws -> WhisperKit {
        if let pipeline { return pipeline }
        if let loadTask { return try await loadTask.value }
        let task = Task<WhisperKit, Error> {
            let config = WhisperKitConfig(
                model: modelVariant,
                modelRepo: modelRepo,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: true
            )
            return try await WhisperKit(config)
        }
        loadTask = task
        let kit = try await task.value
        pipeline = kit
        loadTask = nil
        return kit
    }
}
