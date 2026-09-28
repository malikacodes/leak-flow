import Foundation

/// Keeps the most recent transcriptions so they can be copied again later
final class TranscriptHistory {
    static let shared = TranscriptHistory()

    struct Entry: Codable, Equatable {
        let text: String
        let date: Date
    }

    /// How many transcriptions to keep; older ones are dropped
    static let maxEntries = 5

    private let defaults: UserDefaults
    private let key = "transcriptHistory"

    /// Newest first
    private(set) var entries: [Entry] = []

    private convenience init() {
        self.init(defaults: .standard)
    }

    /// Initialize with a specific UserDefaults instance (for testing)
    init(defaults: UserDefaults) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = saved
        }
    }

    /// Add a transcription, keeping only the newest few
    func add(_ text: String, at date: Date = Date()) {
        entries.insert(Entry(text: text, date: date), at: 0)
        entries = Array(entries.prefix(Self.maxEntries))

        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }
}
