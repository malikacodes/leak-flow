import Foundation
import WhisperCpp

/// Wraps whisper.cpp for local speech-to-text transcription
final class WhisperTranscriber: Transcribing {

    private var whisperContext: OpaquePointer?
    private(set) var isModelLoaded = false
    private let processingQueue = DispatchQueue(label: "com.malikapixels.leakflow.transcription", qos: .userInitiated)

    /// Speed setting: use "flash attention," a faster way for the graphics chip
    /// to do the model's heaviest math. Same result, less work.
    var useFlashAttention = true

    deinit {
        unloadModel()
    }

    /// Load a whisper model from the specified file path
    func loadModel(at path: String) throws {
        unloadModel()

        guard FileManager.default.fileExists(atPath: path) else {
            throw TranscriberError.modelNotFound(path)
        }

        var cparams = whisper_context_default_params()
        cparams.flash_attn = useFlashAttention
        let context = whisper_init_from_file_with_params(path, cparams)

        guard let context = context else {
            throw TranscriberError.modelLoadFailed
        }

        whisperContext = context
        isModelLoaded = true
        print("WhisperTranscriber: Model loaded from \(path)")

        warmUp()
    }

    /// Run the model once on a second of silence right after it loads.
    ///
    /// The very first time the graphics chip runs the model, it has to get set up
    /// (like a car engine on a cold morning), which makes your first recording slow.
    /// Doing it here, in the background, means you never feel that delay.
    private func warmUp() {
        let silence = [Float](repeating: 0, count: 16_000) // 1 second of quiet (16,000 samples = 1 second)
        Task { _ = try? await transcribe(samples: silence, prompt: nil) }
    }

    /// Transcribe audio samples to text
    func transcribe(samples: [Float], prompt: String?) async throws -> String {
        guard let context = whisperContext else {
            throw TranscriberError.noModelLoaded
        }

        guard !samples.isEmpty else {
            throw TranscriberError.emptySamples
        }

        nonisolated(unsafe) let ctx = context
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                let strategy = whisper_sampling_strategy(rawValue: 0) // WHISPER_SAMPLING_GREEDY
                var params: whisper_full_params = whisper_full_default_params(strategy)
                params.n_threads = 4

                // Timestamps stay on, even though the text never shows them. They're
                // Whisper's bookmark: how it knows how far into the 30-second window
                // it has read. With them off, if it decided I was done after my first
                // sentence (a pause is enough), it skipped everything else in that
                // window and the rest of what I said was just gone.
                params.no_timestamps = false
                params.single_segment = false
                params.print_progress = false
                params.print_realtime = false
                params.print_special = false
                params.print_timestamps = false

                // No trimming the 30-second window (audio_ctx stays at its default).
                // I used to shrink it to the length of what I said, to save about a
                // third of a second. But the model stays loaded between recordings,
                // and after a longer recording a shorter one lost its last few words.
                // The same audio came back whole with the full window.

                // My Words, handed over as the hint Whisper reads before listening.
                // whisper.cpp only borrows the text, so it has to run inside
                // withCString: outside that block the C copy of the string is gone.
                func run(_ params: whisper_full_params) -> Int32 {
                    samples.withUnsafeBufferPointer { bufferPointer in
                        whisper_full(ctx, params, bufferPointer.baseAddress, Int32(samples.count))
                    }
                }
                let result: Int32
                if let prompt {
                    result = prompt.withCString { promptPointer in
                        params.initial_prompt = promptPointer
                        return run(params)
                    }
                } else {
                    result = run(params)
                }

                if result != 0 {
                    continuation.resume(throwing: TranscriberError.transcriptionFailed)
                    return
                }

                let segmentCount = whisper_full_n_segments(ctx)
                var transcription = ""

                for i in 0..<segmentCount {
                    if let segmentText = whisper_full_get_segment_text(ctx, i) {
                        transcription += String(cString: segmentText)
                    }
                }

                let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: trimmed)
            }
        }
    }

    /// Unload the current model and free resources
    func unloadModel() {
        if let context = whisperContext {
            whisper_free(context)
            whisperContext = nil
        }
        isModelLoaded = false
    }
}

/// Errors that can occur during transcription
enum TranscriberError: LocalizedError {
    case modelNotFound(String)
    case modelLoadFailed
    case noModelLoaded
    case emptySamples
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Whisper model not found at: \(path)"
        case .modelLoadFailed:
            return "Failed to load whisper model"
        case .noModelLoaded:
            return "No whisper model loaded"
        case .emptySamples:
            return "No audio samples to transcribe"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
