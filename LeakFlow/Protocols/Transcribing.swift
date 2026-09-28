import Foundation

/// Protocol defining speech-to-text transcription capabilities
protocol Transcribing {
    /// Whether a model is currently loaded and ready
    var isModelLoaded: Bool { get }

    /// Load a whisper model from the specified file path
    func loadModel(at path: String) throws

    /// Transcribe audio samples to text
    /// - Parameter samples: Float32 PCM audio samples at 16kHz
    /// - Returns: Transcribed text string
    func transcribe(samples: [Float]) async throws -> String

    /// Unload the current model and free resources
    func unloadModel()
}
