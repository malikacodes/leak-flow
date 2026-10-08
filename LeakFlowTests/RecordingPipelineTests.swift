import XCTest
@testable import LeakFlow

final class RecordingPipelineTests: XCTestCase {

    var mockRecorder: MockAudioRecorder!
    var mockTranscriber: MockTranscriber!
    var mockOutput: MockTextOutputManager!
    var pipeline: RecordingPipeline!

    override func setUp() {
        super.setUp()
        mockRecorder = MockAudioRecorder()
        mockTranscriber = MockTranscriber()
        mockOutput = MockTextOutputManager()
        pipeline = RecordingPipeline(
            recorder: mockRecorder,
            transcriber: mockTranscriber,
            textOutput: mockOutput
        )
    }

    // MARK: - startRecording

    func testStartRecording_setsRecorderRecording() throws {
        try pipeline.startRecording()
        XCTAssertTrue(mockRecorder.isRecording)
        XCTAssertEqual(mockRecorder.startRecordingCallCount, 1)
    }

    // Protects against the pearl lying: if the last recording is still being
    // transcribed, starting a new one has to fail loudly, not pretend to record.
    func testStartRecording_whileTranscribing_throws() async throws {
        mockRecorder.samplesToReturn = [0.1, 0.2]
        mockTranscriber.isModelLoaded = true

        // Hold the transcription open until the test lets it finish
        let transcribing = expectation(description: "transcription is in progress")
        var finish: CheckedContinuation<Void, Never>?
        mockTranscriber.beforeReturning = {
            await withCheckedContinuation { continuation in
                finish = continuation
                transcribing.fulfill()
            }
        }

        let running = Task {
            await pipeline.stopRecordingAndTranscribe(autoPaste: false, copyToClipboard: false)
        }
        await fulfillment(of: [transcribing], timeout: 2)

        XCTAssertThrowsError(try pipeline.startRecording()) { error in
            XCTAssertEqual(error as? RecordingPipelineError, .stillTranscribing)
        }
        XCTAssertEqual(mockRecorder.startRecordingCallCount, 0)

        // Once it's done, recording works again
        finish?.resume()
        await running.value
        XCTAssertNoThrow(try pipeline.startRecording())
        XCTAssertEqual(mockRecorder.startRecordingCallCount, 1)
    }

    func testStartRecording_recorderThrows_propagatesError() {
        let expectedError = NSError(domain: "test", code: 42)
        mockRecorder.startRecordingShouldThrow = expectedError
        XCTAssertThrowsError(try pipeline.startRecording()) { error in
            XCTAssertEqual((error as NSError).code, 42)
        }
    }

    // MARK: - stopRecordingAndTranscribe

    func testStopAndTranscribe_emptySamples_skipsTranscription() async {
        mockRecorder.samplesToReturn = []
        mockTranscriber.isModelLoaded = true
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
        XCTAssertEqual(mockTranscriber.transcribeCallCount, 0)
        XCTAssertEqual(mockOutput.outputCallCount, 0)
    }

    func testStopAndTranscribe_modelNotLoaded_skipsTranscription() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = false
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
        XCTAssertEqual(mockTranscriber.transcribeCallCount, 0)
        XCTAssertEqual(mockOutput.outputCallCount, 0)
    }

    func testStopAndTranscribe_success_outputsText() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = true
        mockTranscriber.textToReturn = "hello world"
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
        XCTAssertEqual(mockOutput.outputCallCount, 1)
        XCTAssertEqual(mockOutput.lastCopiedText, "hello world")
        XCTAssertEqual(mockOutput.lastAutoPasteValue, true)
        XCTAssertFalse(pipeline.isProcessing)
    }

    func testStopAndTranscribe_success_withoutAutoPaste() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = true
        mockTranscriber.textToReturn = "hello world"
        await pipeline.stopRecordingAndTranscribe(autoPaste: false, copyToClipboard: true)
        XCTAssertEqual(mockOutput.lastAutoPasteValue, false)
    }

    func testStopAndTranscribe_transcriptionFails_resetsProcessing() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = true
        mockTranscriber.transcribeShouldThrow = NSError(domain: "test", code: 1)
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
        XCTAssertFalse(pipeline.isProcessing)
        XCTAssertEqual(mockOutput.outputCallCount, 0)
    }

    func testStopAndTranscribe_emptyTranscription_doesNotOutput() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = true
        mockTranscriber.textToReturn = "   \n  "
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
        XCTAssertEqual(mockOutput.outputCallCount, 0)
        XCTAssertFalse(pipeline.isProcessing)
    }
}
