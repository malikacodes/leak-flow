import Foundation
import WhisperCpp

/// Wraps whisper.cpp for local speech-to-text transcription
final class WhisperTranscriber: Transcribing {

    private var whisperContext: OpaquePointer?
    private(set) var isModelLoaded = false
    private let processingQueue = DispatchQueue(label: "com.malikapixels.leakflow.transcription", qos: .userInitiated)

    deinit {
        unloadModel()
    }

    /// Load a whisper model from the specified file path
    func loadModel(at path: String) throws {
        unloadModel()

        guard FileManager.default.fileExists(atPath: path) else {
            throw TranscriberError.modelNotFound(path)
        }

        let cparams = whisper_context_default_params()
        let context = whisper_init_from_file_with_params(path, cparams)

        guard let context = context else {
            throw TranscriberError.modelLoadFailed
        }

        whisperContext = context
        isModelLoaded = true
        print("WhisperTranscriber: Model loaded from \(path)")
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
