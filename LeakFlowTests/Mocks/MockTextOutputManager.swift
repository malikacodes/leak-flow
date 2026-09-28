import Foundation
@testable import LeakFlow

/// Mock text output manager for testing
final class MockTextOutputManager: TextOutputting {
    var lastCopiedText: String?
    var pasteCallCount = 0
    var outputCallCount = 0
    var lastAutoPasteValue: Bool?

    func copyToClipboard(_ text: String) {
        lastCopiedText = text
    }

    func pasteFromClipboard() {
        pasteCallCount += 1
    }

    var lastCopyToClipboardValue: Bool?

    func output(text: String, autoPaste: Bool, copyToClipboard: Bool) {
        outputCallCount += 1
        lastCopiedText = text
        lastAutoPasteValue = autoPaste
        lastCopyToClipboardValue = copyToClipboard
    }
}
