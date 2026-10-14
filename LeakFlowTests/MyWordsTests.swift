import XCTest
@testable import LeakFlow

final class MyWordsTests: XCTestCase {

    // MARK: - Reading the Settings boxes

    // Protects the Settings boxes from stray blank lines and spaces turning
    // into empty words that would end up in Whisper's hint.
    func testWordsText_skipsBlankLinesAndTrims() {
        let myWords = MyWords(wordsText: "  Malika \n\n Leak Flow\n   \n", fixesText: "")
        XCTAssertEqual(myWords.words, ["Malika", "Leak Flow"])
    }

    // Protects both arrow spellings, since macOS can turn -> into → while I type.
    func testFixesText_acceptsBothArrows() {
        let myWords = MyWords(wordsText: "", fixesText: "sims four -> Sims 4\nmy kit → MCIT")
        XCTAssertEqual(myWords.fixes, [
            MyWords.Fix(heard: "sims four", write: "Sims 4"),
            MyWords.Fix(heard: "my kit", write: "MCIT")
        ])
    }

    // Protects against half-typed fix lines doing something weird: no arrow
    // or nothing before it means the line is ignored, not guessed at.
    func testFixesText_ignoresLinesItCantRead() {
        let myWords = MyWords(wordsText: "", fixesText: "just some words\n -> Sims 4\na -> b -> c")
        XCTAssertEqual(myWords.fixes, [])
    }

    // MARK: - The hint for Whisper

    // Protects the "no words, no hint" case, so an empty list leaves Whisper
    // exactly as it was before My Words existed.
    func testPrompt_isNilWithNoWords() {
        XCTAssertNil(MyWords().prompt)
    }

    func testPrompt_joinsWordsLikeASentence() {
        let myWords = MyWords(words: ["Malika", "Leak Flow", "MCIT"])
        XCTAssertEqual(myWords.prompt, "Malika, Leak Flow, MCIT.")
    }

    // MARK: - Fixes

    // Protects the main job of a fix: Whisper's capital at the start of a
    // sentence still matches a fix typed in lowercase.
    func testApplyFixes_ignoresCase() {
        let myWords = MyWords(fixes: [MyWords.Fix(heard: "leak flow", write: "Leak Flow")])
        XCTAssertEqual(
            myWords.applyFixes(to: "Leak flow is cute. I love leak flow."),
            "Leak Flow is cute. I love Leak Flow."
        )
    }

    // Protects other words from getting chewed up: a fix only matches whole
    // words, never the middle of a longer one.
    func testApplyFixes_onlyMatchesWholeWords() {
        let myWords = MyWords(fixes: [MyWords.Fix(heard: "sim", write: "Sim")])
        XCTAssertEqual(myWords.applyFixes(to: "a sim, simple simulation"), "a Sim, simple simulation")
    }

    // Protects fixes with symbols in them. Characters like $ and . mean
    // something special to the search, so they have to be taken literally.
    func testApplyFixes_treatsSymbolsLiterally() {
        let myWords = MyWords(fixes: [MyWords.Fix(heard: "dot net", write: "$1.NET")])
        XCTAssertEqual(myWords.applyFixes(to: "I tried dot net once"), "I tried $1.NET once")
    }
}
