import Foundation
import AVFoundation
import Combine
import AppKit

/// Manages checking and requesting system permissions
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var microphoneGranted = false
    @Published var accessibilityGranted = false

    private var timer: Timer?

    private init() {
        checkPermissions()
        startPollingPermissions()
    }

    deinit {
        timer?.invalidate()
    }

    /// Check all permissions
    func checkPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    /// Check microphone permission status
    func checkMicrophonePermission() {
        let granted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if Thread.isMainThread {
            microphoneGranted = granted
        } else {
            DispatchQueue.main.async { self.microphoneGranted = granted }
        }
    }

    /// Request microphone access
    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphoneGranted = granted
                completion(granted)
            }
        }
    }

    /// Check accessibility permission
    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if Thread.isMainThread {
            accessibilityGranted = trusted
        } else {
            DispatchQueue.main.async { self.accessibilityGranted = trusted }
        }
    }

    /// Prompt for accessibility permission
    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to Accessibility pane
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings to Microphone pane
    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Poll permissions periodically (they can change while app is running)
    private func startPollingPermissions() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkMicrophonePermission()
            self?.checkAccessibilityPermission()
        }
    }
}
