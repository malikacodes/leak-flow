import XCTest
@testable import LeakFlow

final class WhisperModelTests: XCTestCase {

    func testAllCases_haveNonEmptyDisplayNames() {
        for model in ModelDownloader.WhisperModel.allCases {
            XCTAssertFalse(model.displayName.isEmpty, "\(model.rawValue) has empty displayName")
        }
    }

    func testAllCases_haveFileNamesEndingInBin() {
        for model in ModelDownloader.WhisperModel.allCases {
            XCTAssertTrue(
                model.fileName.hasSuffix(".bin"),
                "\(model.rawValue) fileName '\(model.fileName)' doesn't end in .bin"
            )
        }
    }

    func testAllCases_haveValidDownloadURLs() {
        for model in ModelDownloader.WhisperModel.allCases {
            let url = model.downloadURL
            XCTAssertTrue(
                url.absoluteString.contains("huggingface.co"),
                "\(model.rawValue) URL doesn't contain huggingface.co"
            )
            XCTAssertTrue(
                url.absoluteString.contains(model.fileName),
                "\(model.rawValue) URL doesn't contain fileName"
            )
        }
    }

    func testBaseEN_fileName() {
        XCTAssertEqual(ModelDownloader.WhisperModel.baseEN.fileName, "ggml-base.en.bin")
    }

    func testSmallEN_fileName() {
        XCTAssertEqual(ModelDownloader.WhisperModel.smallEN.fileName, "ggml-small.en.bin")
    }

    func testAllModels_haveUniqueFileNames() {
        let fileNames = ModelDownloader.WhisperModel.allCases.map { $0.fileName }
        XCTAssertEqual(fileNames.count, Set(fileNames).count, "Duplicate fileNames found")
    }
}
