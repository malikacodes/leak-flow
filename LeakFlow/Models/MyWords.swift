import Foundation

/// My own words: names and spellings Whisper keeps getting wrong.
///
/// Two parts, both typed in Settings as plain text, one per line:
/// - words, like "Malika" or "Leak Flow". These go to Whisper before it
///   listens, as a hint for how to spell things.
/// - fixes, like "sims four -> Sims 4". These run on the text after Whisper
///   is done, for the times the hint isn't enough.
///
/// Wispr Flow sends the same two things to its servers (a personal
/// dictionary and replacements). Here they never leave the Mac.
struct MyWords: Equatable {
    struct Fix: Equatable {
        let heard: String
        let write: String
    }

    let words: [String]
    let fixes: [Fix]

    init(words: [String] = [], fixes: [Fix] = []) {
        self.words = words
        self.fixes = fixes
    }

    /// Build from the two text boxes in Settings
    init(wordsText: String, fixesText: String) {
        self.words = MyWords.lines(in: wordsText)
        self.fixes = MyWords.lines(in: fixesText).compactMap(MyWords.parseFix)
    }

    /// The hint Whisper reads before it listens, or nil when there are no words.
    ///
    /// Whisper treats this as "what was said just before", so a plain list with
    /// commas reads to it like a sentence that used these spellings. It only
    /// reads about 224 tokens (word pieces) of it, and anything past that is
    /// ignored, which is plenty for a personal list.
    var prompt: String? {
        words.isEmpty ? nil : words.joined(separator: ", ") + "."
    }

    /// Swap every fix into the text, ignoring upper and lower case.
    ///
    /// Only whole words match, so a fix for "leak" won't touch "leaking".
    func applyFixes(to text: String) -> String {
        fixes.reduce(text) { result, fix in
            let pattern = "(?<![\\w])" + NSRegularExpression.escapedPattern(for: fix.heard) + "(?![\\w])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return result
            }
            let range = NSRange(result.startIndex..., in: result)
            return regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: fix.write)
            )
        }
    }

    /// Non-empty, trimmed lines
    private static func lines(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// "heard -> write". The arrow can be typed as -> or →, since macOS
    /// sometimes turns -> into → on its own while I type.
    private static func parseFix(_ line: String) -> Fix? {
        for arrow in ["->", "→"] {
            let parts = line.components(separatedBy: arrow)
            guard parts.count == 2 else { continue }
            let heard = parts[0].trimmingCharacters(in: .whitespaces)
            let write = parts[1].trimmingCharacters(in: .whitespaces)
            guard !heard.isEmpty else { return nil }
            return Fix(heard: heard, write: write)
        }
        return nil
    }
}
