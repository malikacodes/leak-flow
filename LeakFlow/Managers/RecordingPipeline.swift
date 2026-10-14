import Foundation
import os

/// Orchestrates the recording and transcription pipeline
final class RecordingPipeline {
    private let recorder: AudioRecording
    private let transcriber: Transcribing
    private let textOutput: TextOutputting

    /// Whether the pipeline is currently processing a transcription
    private(set) var isProcessing = false

    /// One line per recording: how long I talked and how many words came back.
    /// The words themselves are never written down, only the counts.
    /// To read it: log show --last 1h --predicate 'subsystem == "com.malikapixels.leakflow"'
    private let log = Logger(subsystem: "com.malikapixels.leakflow", category: "recording")

    /// My word list and fixes. AppDelegate refreshes this from Settings
    /// before each transcription, so edits count from the next recording.
    var myWords = MyWords()

    /// Called when an error occurs during the pipeline
    var onError: ((Error) -> Void)?

    /// Called when transcription completes successfully
    var onTranscriptionComplete: ((String) -> Void)?

    /// Initialize with protocol dependencies for testability
    init(recorder: AudioRecording, transcriber: Transcribing, textOutput: TextOutputting) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.textOutput = textOutput
    }

    /// Start recording audio
    func startRecording() throws {
        // This used to return quietly, so the pearl showed up and I talked to
        // nothing. Throwing means the app only looks like it's recording when it is.
        guard !isProcessing else {
            log.notice("key pressed while the last recording was still transcribing, not recording")
            throw RecordingPipelineError.stillTranscribing
        }
        try recorder.startRecording()
    }

    /// Stop recording and transcribe the captured audio
    func stopRecordingAndTranscribe(autoPaste: Bool, copyToClipboard: Bool) async {
        let samples = recorder.stopRecording()

        // 16,000 samples is one second of audio
        let seconds = Double(samples.count) / 16_000

        guard !samples.isEmpty else {
            log.notice("key released but no audio was captured")
            return
        }

        guard transcriber.isModelLoaded else {
            print("RecordingPipeline: Model not loaded, cannot transcribe")
            return
        }

        isProcessing = true

        do {
            let text = try await transcriber.transcribe(samples: samples, prompt: myWords.prompt)
            let trimmed = myWords.applyFixes(to: text).trimmingCharacters(in: .whitespacesAndNewlines)

            // Short seconds means the recording stopped early (key or mic).
            // Plenty of seconds and few words means Whisper dropped them.
            let words = trimmed.split(whereSeparator: \.isWhitespace).count
            log.notice("recorded \(seconds, format: .fixed(precision: 1)) seconds, got \(words) words")

            guard !trimmed.isEmpty else {
                print("RecordingPipeline: Transcription returned empty text")
                isProcessing = false
                return
            }

            textOutput.output(text: trimmed, autoPaste: autoPaste, copyToClipboard: copyToClipboard)
            onTranscriptionComplete?(trimmed)
            isProcessing = false
        } catch {
            print("RecordingPipeline: Transcription failed: \(error)")
            onError?(error)
            isProcessing = false
        }
    }
}

/// Errors that can occur before recording starts
enum RecordingPipelineError: LocalizedError {
    case stillTranscribing

    var errorDescription: String? {
        switch self {
        case .stillTranscribing:
            return "Still transcribing the last recording"
        }
    }
}
