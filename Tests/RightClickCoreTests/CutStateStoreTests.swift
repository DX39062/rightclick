import XCTest
@testable import RightClickCore

final class CutStateStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingStateReturnsNil() throws {
        let store = CutStateStore(directory: directory)
        XCTAssertNil(try store.load())
    }

    func testSavesAndLoadsState() throws {
        let store = CutStateStore(directory: directory)
        let state = CutState(itemURLs: [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/folder", isDirectory: true)
        ])

        try store.save(state)

        XCTAssertEqual(try store.load(), state)
    }

    func testClearRemovesState() throws {
        let store = CutStateStore(directory: directory)
        try store.save(CutState(itemURLs: [URL(fileURLWithPath: "/tmp/a.txt")]))

        try store.clear()

        XCTAssertNil(try store.load())
    }

    func testMalformedStateReturnsNil() throws {
        let store = CutStateStore(directory: directory)
        try "{not-json".write(to: store.stateURL, atomically: true, encoding: .utf8)

        XCTAssertNil(try store.load())
    }
}
