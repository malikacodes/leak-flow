import Foundation
import Combine
import ServiceManagement

/// Manages app settings persisted via UserDefaults
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    private enum Keys {
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifierFlags = "hotkeyModifierFlags"
        static let hotkeyIsModifierOnly = "hotkeyIsModifierOnly"
        static let selectedModel = "selectedModel"
        static let autoPasteEnabled = "autoPasteEnabled"
        static let copyToClipboardEnabled = "copyToClipboardEnabled"
        static let playSoundsEnabled = "playSoundsEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    /// The currently configured hotkey binding
    @Published var hotkeyBinding: HotkeyBinding {
        didSet {
            defaults.set(Int(hotkeyBinding.keyCode), forKey: Keys.hotkeyKeyCode)
            defaults.set(hotkeyBinding.modifierFlags, forKey: Keys.hotkeyModifierFlags)
            defaults.set(hotkeyBinding.isModifierOnly, forKey: Keys.hotkeyIsModifierOnly)
        }
    }

    /// The selected whisper model name
    @Published var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Keys.selectedModel) }
    }

    /// Whether to auto-paste transcribed text
    @Published var autoPasteEnabled: Bool {
        didSet {
            defaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled)
            if !autoPasteEnabled {
                copyToClipboardEnabled = true
            }
        }
    }

    /// Whether to copy transcribed text to clipboard
    @Published var copyToClipboardEnabled: Bool {
        didSet { defaults.set(copyToClipboardEnabled, forKey: Keys.copyToClipboardEnabled) }
    }

    /// Whether to play sounds on record start/stop
    @Published var playSoundsEnabled: Bool {
        didSet { defaults.set(playSoundsEnabled, forKey: Keys.playSoundsEnabled) }
    }

    /// Whether to launch at login
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    private convenience init() {
        self.init(defaults: .standard)
    }

    /// Initialize with a specific UserDefaults instance (for testing)
    init(defaults: UserDefaults) {
        self.defaults = defaults

        let savedKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) as? Int
        let savedModifierFlags = defaults.object(forKey: Keys.hotkeyModifierFlags) as? UInt
        let savedIsModifierOnly = defaults.object(forKey: Keys.hotkeyIsModifierOnly) as? Bool

        if let keyCode = savedKeyCode, let flags = savedModifierFlags, let modOnly = savedIsModifierOnly {
            self.hotkeyBinding = HotkeyBinding(
                keyCode: UInt16(keyCode),
                modifierFlags: flags,
                isModifierOnly: modOnly
            )
        } else {
            self.hotkeyBinding = HotkeyBinding.defaultBinding
        }

        self.selectedModel = defaults.string(forKey: Keys.selectedModel) ?? "base.en"
        self.autoPasteEnabled = defaults.object(forKey: Keys.autoPasteEnabled) as? Bool ?? true
        self.copyToClipboardEnabled = defaults.object(forKey: Keys.copyToClipboardEnabled) as? Bool ?? true
        self.playSoundsEnabled = defaults.object(forKey: Keys.playSoundsEnabled) as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}
