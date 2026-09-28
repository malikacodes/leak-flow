import Foundation

/// Protocol defining text output capabilities (clipboard + paste)
protocol TextOutputting {
    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String)

    /// Paste clipboard contents into the active text field via simulated Cmd+V
    func pasteFromClipboard()

    /// Copy text and optionally paste it
    func output(text: String, autoPaste: Bool, copyToClipboard: Bool)
}
