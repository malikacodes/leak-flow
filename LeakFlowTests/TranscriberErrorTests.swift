import XCTest
@testable import LeakFlow

final class TranscriberErrorTests: XCTestCase {

    func testModelNotFound_includesPath() {
        let error = TranscriberError.modelNotFound("/path/to/model.bin")
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("/path/to/model.bin"))
    }

    func testModelLoadFailed_hasDescription() {
        let error = TranscriberError.modelLoadFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testNoModelLoaded_hasDescription() {
        let error = TranscriberError.noModelLoaded
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testEmptySamples_hasDescription() {
        let error = TranscriberError.emptySamples
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testTranscriptionFailed_hasDescription() {
        let error = TranscriberError.transcriptionFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }
}
