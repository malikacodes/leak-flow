import Foundation
@testable import LeakFlow

/// Mock audio recorder for testing
final class MockAudioRecorder: AudioRecording {
    var isRecording = false
    var startRecordingShouldThrow: Error?
    var samplesToReturn: [Float] = []
    var startRecordingCallCount = 0
    var stopRecordingCallCount = 0

    func startRecording() throws {
        if let error = startRecordingShouldThrow { throw error }
        startRecordingCallCount += 1
        isRecording = true
    }

    func stopRecording() -> [Float] {
        stopRecordingCallCount += 1
        isRecording = false
        return samplesToReturn
    }
}
