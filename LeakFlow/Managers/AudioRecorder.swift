import Foundation
import AVFoundation
import os

/// Records audio from the default microphone at 16kHz mono Float32 PCM
final class AudioRecorder: AudioRecording {

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private(set) var isRecording = false

    /// Start, stop and the mid-recording restart all touch the engine, and they
    /// can come from different threads. This lock is the "one at a time" sign on
    /// the door, so a restart can never land in the middle of a stop.
    private let engineLock = NSLock()

    private let log = Logger(subsystem: "com.malikapixels.leakflow", category: "recording")

    init() {
        // macOS stops the engine whenever the sound setup changes: a different
        // mic, a different output, even an app like FineTune reshuffling devices.
        // Nothing used to notice, so the pearl kept pulsing while the recording
        // had quietly ended and I lost everything I said after that moment.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            self?.resumeAfterDeviceChange()
        }
    }

    /// Start recording audio from the default microphone
    func startRecording() throws {
        engineLock.lock()
        defer { engineLock.unlock() }

        guard !isRecording else { return }

        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()

        try startEngine()
        isRecording = true
    }

    /// Stop recording and return captured PCM samples
    func stopRecording() -> [Float] {
        engineLock.lock()
        defer { engineLock.unlock() }

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

    /// Hook the microphone up to the buffer and start the engine.
    ///
    /// The mic's format is read fresh every time, because after a device change
    /// the new mic can run at a different sample rate than the old one.
    private func startEngine() throws {
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

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.convertAndAppend(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }

        try audioEngine.start()
    }

    /// Pick the recording back up after macOS stopped the engine underneath it.
    ///
    /// What was already captured stays in the buffer, so the only thing lost is
    /// the split second it takes to switch over.
    private func resumeAfterDeviceChange() {
        engineLock.lock()
        defer { engineLock.unlock() }

        guard isRecording else { return }

        audioEngine.inputNode.removeTap(onBus: 0)

        do {
            try startEngine()
            log.notice("sound setup changed mid-recording, picked the mic back up")
        } catch {
            log.error("sound setup changed mid-recording and the mic wouldn't restart: \(error.localizedDescription, privacy: .public)")
        }
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
