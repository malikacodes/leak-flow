import Foundation
import AVFoundation

/// Records audio from the default microphone at 16kHz mono Float32 PCM
final class AudioRecorder: AudioRecording {

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private(set) var isRecording = false

    /// Start recording audio from the default microphone
    func startRecording() throws {
        guard !isRecording else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioRecorderError.noInputAvailable
        }

        // Target format: 16kHz, mono, Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatError
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterError
        }

        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.convertAndAppend(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }

        try audioEngine.start()
        isRecording = true
    }

    /// Stop recording and return captured PCM samples
    func stopRecording() -> [Float] {
        guard isRecording else { return [] }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        return samples
    }

    private func convertAndAppend(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * (16000.0 / buffer.format.sampleRate)
        )

        guard frameCount > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            return
        }

        var error: NSError?
        var hasData = true

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if let error = error {
            print("AudioRecorder: Conversion error: \(error)")
            return
        }

        guard let channelData = convertedBuffer.floatChannelData else { return }
        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: Int(convertedBuffer.frameLength)
        ))

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()
    }
}

/// Errors that can occur during audio recording
enum AudioRecorderError: LocalizedError {
    case noInputAvailable
    case formatError
    case converterError

    var errorDescription: String? {
        switch self {
        case .noInputAvailable:
            return "No audio input device available"
        case .formatError:
            return "Failed to create target audio format"
        case .converterError:
            return "Failed to create audio format converter"
        }
    }
}
