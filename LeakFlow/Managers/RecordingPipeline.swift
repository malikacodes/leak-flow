import Foundation

/// Orchestrates the recording and transcription pipeline
final class RecordingPipeline {
    private let recorder: AudioRecording
    private let transcriber: Transcribing
    private let textOutput: TextOutputting

    /// Whether the pipeline is currently processing a transcription
    private(set) var isProcessing = false

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
        guard !isProcessing else { return }
        try recorder.startRecording()
    }

    /// Stop recording and transcribe the captured audio
    func stopRecordingAndTranscribe(autoPaste: Bool, copyToClipboard: Bool) async {
        let samples = recorder.stopRecording()

        guard !samples.isEmpty else {
            print("RecordingPipeline: No audio samples captured")
            return
        }

        guard transcriber.isModelLoaded else {
            print("RecordingPipeline: Model not loaded, cannot transcribe")
            return
        }

        isProcessing = true

        do {
            let text = try await transcriber.transcribe(samples: samples)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

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
