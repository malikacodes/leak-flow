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

    /// Speed setting: only make the model read as much audio as you actually said.
    ///
    /// Whisper was built to listen in 30-second chunks. If you talk for 5 seconds,
    /// it normally pads the rest with silence and still reads all 30 seconds, like
    /// reading a whole page when only the first line has writing on it. This tells
    /// it to stop at the end of what you said. (Only used when flash attention is on.)
    var trimToSpeechLength = true

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
        Task { _ = try? await transcribe(samples: silence) }
    }

    /// Transcribe audio samples to text
    func transcribe(samples: [Float]) async throws -> String {
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
                params.no_timestamps = true
                params.single_segment = false
                params.print_progress = false
                params.print_realtime = false
                params.print_special = false
                params.print_timestamps = false

                // Trimming only works safely together with flash attention. Without it,
                // the graphics chip crashes on some recording lengths, so we skip it.
                if self.trimToSpeechLength && self.useFlashAttention {
                    params.audio_ctx = Self.audioContext(forSampleCount: samples.count)
                }

                let result = samples.withUnsafeBufferPointer { bufferPointer in
                    whisper_full(ctx, params, bufferPointer.baseAddress, Int32(samples.count))
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

    /// How much of the 30-second window the model should read for a recording.
    ///
    /// The model reads audio in tiny steps, 50 of them per second, and a full
    /// 30 seconds is 1,500 steps. So a 4-second recording needs about 200 steps.
    /// A little extra is added on top so the last word never gets cut off.
    static func audioContext(forSampleCount sampleCount: Int) -> Int32 {
        let seconds = Double(sampleCount) / 16_000   // the recording is 16,000 samples per second
        let steps = Int(seconds * 50) + 128          // 50 steps per second, plus some breathing room
        return Int32(min(steps, 1500))               // never more than the full 30 seconds
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
