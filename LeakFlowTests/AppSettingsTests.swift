import XCTest
@testable import LeakFlow

final class AppSettingsTests: XCTestCase {

    var defaults: UserDefaults!
    var settings: AppSettings!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "com.malikapixels.leakflow.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = AppSettings(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        settings = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Default Values

    func testDefaultSelectedModel() {
        XCTAssertEqual(settings.selectedModel, "base.en")
    }

    func testDefaultAutoPaste() {
        XCTAssertTrue(settings.autoPasteEnabled)
    }

    func testDefaultPlaySounds() {
        XCTAssertTrue(settings.playSoundsEnabled)
    }

    func testDefaultLaunchAtLogin() {
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testDefaultHotkeyBinding() {
        XCTAssertEqual(settings.hotkeyBinding, HotkeyBinding.defaultBinding)
    }

    // MARK: - Auto-Paste Constraint

    func testDisablingAutoPaste_forcesCopyToClipboardOn() {
        settings.copyToClipboardEnabled = false
        settings.autoPasteEnabled = false
        XCTAssertTrue(settings.copyToClipboardEnabled)
    }

    func testEnablingAutoPaste_doesNotForceCopyToClipboard() {
        settings.copyToClipboardEnabled = false
        settings.autoPasteEnabled = true
        XCTAssertFalse(settings.copyToClipboardEnabled)
    }

    // MARK: - Persistence

    func testHotkeyBinding_persistsToUserDefaults() {
        let binding = HotkeyBinding(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            isModifierOnly: false
        )
        settings.hotkeyBinding = binding

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.hotkeyBinding, binding)
    }
}
