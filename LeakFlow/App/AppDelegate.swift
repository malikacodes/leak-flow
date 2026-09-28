import AppKit
import AVFoundation
import Combine

/// Main application delegate handling lifecycle and wiring all components together
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarManager: MenuBarManager?
    private let audioRecorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let textOutputManager = TextOutputManager()
    private let modelDownloader = ModelDownloader()
    private lazy var recordingPipeline = RecordingPipeline(
        recorder: audioRecorder,
        transcriber: transcriber,
        textOutput: textOutputManager
    )
    private var recordingIndicator: RecordingIndicatorWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPermissions()
        setupMenuBar()
        setupHotkey()
        loadModel()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
        transcriber.unloadModel()
    }

    // MARK: - Setup

    private func setupPermissions() {
        let permManager = PermissionManager.shared

        if !permManager.microphoneGranted {
            permManager.requestMicrophoneAccess { granted in
                if !granted {
                    print("AppDelegate: Microphone access denied")
                }
            }
        }

        if !permManager.accessibilityGranted {
            permManager.requestAccessibilityAccess()
        }
    }

    private func setupMenuBar() {
        menuBarManager = MenuBarManager(modelDownloader: modelDownloader)
        menuBarManager?.setupMenuBar()

        recordingIndicator = RecordingIndicatorWindow()
    }

    private func setupHotkey() {
        let hotkeyManager = HotkeyManager.shared

        hotkeyManager.onHotkeyDown = { [weak self] in
            self?.startRecording()
        }

        hotkeyManager.onHotkeyUp = { [weak self] in
            self?.stopRecordingAndTranscribe()
        }

        hotkeyManager.start()

        // Retry starting the hotkey listener when accessibility permission is granted after launch
        PermissionManager.shared.$accessibilityGranted
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { _ in
                HotkeyManager.shared.start()
            }
            .store(in: &cancellables)
    }

    private func loadModel() {
        let settings = AppSettings.shared
        guard let model = ModelDownloader.WhisperModel(rawValue: settings.selectedModel) else { return }

        if modelDownloader.isModelDownloaded(model) {
            loadModelFile(model)
        } else {
            modelDownloader.downloadModel(model) { [weak self] result in
                switch result {
                case .success:
                    self?.loadModelFile(model)
                case .failure(let error):
                    print("AppDelegate: Failed to download model: \(error)")
                }
            }
        }
    }

    private func loadModelFile(_ model: ModelDownloader.WhisperModel) {
        let path = modelDownloader.modelPath(model)
        do {
            try transcriber.loadModel(at: path)
            print("AppDelegate: Model loaded successfully")
        } catch {
            print("AppDelegate: Failed to load model: \(error)")
        }
    }

    // MARK: - Recording Pipeline

    private func startRecording() {
        do {
            try recordingPipeline.startRecording()
            menuBarManager?.setRecording(true)
            recordingIndicator?.showIndicator()

            if AppSettings.shared.playSoundsEnabled {
                NSSound.tink?.play()
            }
        } catch {
            print("AppDelegate: Failed to start recording: \(error)")
        }
    }

    private func stopRecordingAndTranscribe() {
        menuBarManager?.setRecording(false)
        recordingIndicator?.hideIndicator()

        if AppSettings.shared.playSoundsEnabled {
            NSSound.pop?.play()
        }

        Task {
            await recordingPipeline.stopRecordingAndTranscribe(
                autoPaste: AppSettings.shared.autoPasteEnabled,
                copyToClipboard: AppSettings.shared.copyToClipboardEnabled
            )
        }
    }
}

// MARK: - System Sound Helpers

extension NSSound {
    static let tink = NSSound(named: "Tink")
    static let pop = NSSound(named: "Pop")
}
