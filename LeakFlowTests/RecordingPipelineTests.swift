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

    // Protects the My Words hookup: the word list reaches Whisper as its hint,
    // and the fixes run on what comes back before it gets pasted.
    func testStopAndTranscribe_usesMyWords() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = true
        mockTranscriber.textToReturn = "I play sims four."
        pipeline.myWords = MyWords(wordsText: "Malika\nLeak Flow", fixesText: "sims four -> Sims 4")
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
        XCTAssertEqual(mockTranscriber.lastPrompt, "Malika, Leak Flow.")
        XCTAssertEqual(mockOutput.lastCopiedText, "I play Sims 4.")
    }

    // Protects the order where My Words meets the silence fix: sound labels
    // come out first, so a fix can't turn "[BLANK_AUDIO]" into pasted words.
    func testStopAndTranscribe_silenceWithFixes_pastesNothing() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = true
        mockTranscriber.textToReturn = "[BLANK_AUDIO]"
        pipeline.myWords = MyWords(wordsText: "", fixesText: "[blank_audio] -> hello")
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
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

    // Protects against pasting Whisper's silence label. The real Small model
    // gives back exactly "[BLANK_AUDIO]" for a silent recording.
    func testStopAndTranscribe_blankAudio_doesNotOutput() async {
        mockRecorder.samplesToReturn = [0.1, 0.2, 0.3]
        mockTranscriber.isModelLoaded = true
        mockTranscriber.textToReturn = "[BLANK_AUDIO]"
        var completed: String?
        pipeline.onTranscriptionComplete = { completed = $0 }
        await pipeline.stopRecordingAndTranscribe(autoPaste: true, copyToClipboard: true)
        XCTAssertEqual(mockOutput.outputCallCount, 0)
        XCTAssertNil(completed, "nothing should land in the last 5 recordings either")
        XCTAssertFalse(pipeline.isProcessing)
    }

    // MARK: - withoutSoundLabels

    // A faint hiss came back as "(crickets chirping)" from the real model,
    // so a result that's only parentheses counts as nothing.
    func testSoundLabels_onlyParentheses_becomesEmpty() {
        XCTAssertEqual(RecordingPipeline.withoutSoundLabels("(crickets chirping)"), "")
        XCTAssertEqual(RecordingPipeline.withoutSoundLabels(" (music) [BLANK_AUDIO] "), "")
    }

    // The filter must never eat my words: a label next to speech goes, but
    // real parentheses in the middle of a sentence stay.
    func testSoundLabels_keepsSpeech() {
        XCTAssertEqual(
            RecordingPipeline.withoutSoundLabels("Send it today. [BLANK_AUDIO] Thanks."),
            "Send it today. Thanks."
        )
        XCTAssertEqual(
            RecordingPipeline.withoutSoundLabels("The notes (see below) are done."),
            "The notes (see below) are done."
        )
    }
}
