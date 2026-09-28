import XCTest
@testable import LeakFlow

final class ModelDownloaderDataTests: XCTestCase {

    func testModelsDirectory_isInApplicationSupport() {
        let dir = ModelDownloader.modelsDirectory.path
        XCTAssertTrue(
            dir.contains("Application Support/LeakFlow/Models"),
            "modelsDirectory path '\(dir)' doesn't contain expected components"
        )
    }

    func testModelPath_containsModelsDirectory() {
        let downloader = ModelDownloader()
        let path = downloader.modelPath(.baseEN)
        let modelsDir = ModelDownloader.modelsDirectory.path
        XCTAssertTrue(path.hasPrefix(modelsDir), "modelPath doesn't start with modelsDirectory")
    }

    func testModelPath_endsWithFileName() {
        let downloader = ModelDownloader()
        for model in ModelDownloader.WhisperModel.allCases {
            let path = downloader.modelPath(model)
            XCTAssertTrue(
                path.hasSuffix(model.fileName),
                "\(model.rawValue) path doesn't end with fileName"
            )
        }
    }

    func testAllModels_haveUniqueFileNames() {
        let names = ModelDownloader.WhisperModel.allCases.map { $0.fileName }
        XCTAssertEqual(names.count, Set(names).count)
    }
}
