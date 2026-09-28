import Foundation

/// Protocol defining audio recording capabilities
protocol AudioRecording {
    /// Whether audio is currently being recorded
    var isRecording: Bool { get }

    /// Start recording audio from the default microphone
    func startRecording() throws

    /// Stop recording and return the captured PCM audio samples
    /// - Returns: Array of Float32 PCM samples at 16kHz mono
    func stopRecording() -> [Float]
}
