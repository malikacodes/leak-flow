import AppKit
import SwiftUI

/// Manages the menu bar status item and its menu
final class MenuBarManager {

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let modelDownloader: ModelDownloader

    init(modelDownloader: ModelDownloader) {
        self.modelDownloader = modelDownloader
    }

    /// Set up the menu bar status item
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            button.image = icon
        }

        updateMenu()
    }

    /// Update the menu bar icon to indicate recording state
    func setRecording(_ isRecording: Bool) {
        if let button = statusItem?.button {
            if isRecording {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Leak Flow Recording")
                button.image?.size = NSSize(width: 16, height: 16)
            } else {
                let icon = NSImage(named: "MenuBarIcon")
                icon?.isTemplate = true
                button.image = icon
            }
        }
    }

    /// Update the menu items
    private func updateMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About Leak Flow", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Leak Flow", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(modelDownloader: modelDownloader)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Leak Flow Settings"
            window.contentView = NSHostingView(rootView: settingsView)
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
