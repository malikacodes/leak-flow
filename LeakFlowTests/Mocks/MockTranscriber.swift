import Foundation
@testable import LeakFlow

/// Mock transcriber for testing
final class MockTranscriber: Transcribing {
    var isModelLoaded = false
    var textToReturn = "hello world"
    var transcribeShouldThrow: Error?
    var loadModelShouldThrow: Error?
    var transcribeCallCount = 0
    var lastTranscribedSamples: [Float]?
    var lastPrompt: String?
    /// Runs in the middle of transcribe, so a test can keep it "busy" for a while
    var beforeReturning: (() async -> Void)?

    func loadModel(at path: String) throws {
        if let error = loadModelShouldThrow { throw error }
        isModelLoaded = true
    }

    func transcribe(samples: [Float], prompt: String?) async throws -> String {
        transcribeCallCount += 1
        lastTranscribedSamples = samples
        lastPrompt = prompt
        if let error = transcribeShouldThrow { throw error }
        await beforeReturning?()
        return textToReturn
    }

    func unloadModel() {
        isModelLoaded = false
    }
}
