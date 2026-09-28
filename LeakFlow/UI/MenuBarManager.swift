import AppKit
import SwiftUI

/// Manages the menu bar status item and its menu
final class MenuBarManager: NSObject {

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var pulseTimer: Timer?
    private let modelDownloader: ModelDownloader

    init(modelDownloader: ModelDownloader) {
        self.modelDownloader = modelDownloader
        super.init()
    }

    /// Set up the menu bar status item
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = Self.dotImage(alpha: 1.0)

        updateMenu()
    }

    /// Pulse the pink menu bar dot while recording
    func setRecording(_ isRecording: Bool) {
        pulseTimer?.invalidate()
        pulseTimer = nil
        statusItem?.button?.image = Self.dotImage(alpha: 1.0)

        guard isRecording else { return }

        var dimmed = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            dimmed.toggle()
            self?.statusItem?.button?.image = Self.dotImage(alpha: dimmed ? 0.35 : 1.0)
        }
    }

    /// A small rose-colored dot for the menu bar
    private static func dotImage(alpha: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.leakRose.withAlphaComponent(alpha).setFill() // the deeper rose, so it shows up on a light menu bar
            NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Leak Flow"
        return image
    }

    /// Build the menu; it is rebuilt each time it opens so the history is current
    private func updateMenu() {
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()

        let history = TranscriptHistory.shared.entries
        let header = NSMenuItem(title: history.isEmpty ? "No recordings yet" : "Recent (click to copy)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for entry in history {
            let item = NSMenuItem(title: Self.menuTitle(for: entry), action: #selector(copyHistoryEntry(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.text
            item.toolTip = entry.text
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

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
    }

    /// "3:42 PM   First few words of what was said…"
    private static func menuTitle(for entry: TranscriptHistory.Entry) -> String {
        let time = entry.date.formatted(date: .omitted, time: .shortened)
        let preview = entry.text.count > 40 ? entry.text.prefix(40) + "…" : entry.text
        return "\(time)   \(preview)"
    }

    @objc private func copyHistoryEntry(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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

extension MenuBarManager: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }
}
