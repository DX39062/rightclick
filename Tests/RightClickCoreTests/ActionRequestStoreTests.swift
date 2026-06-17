import XCTest
@testable import RightClickCore

final class ActionRequestStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testWritesAndReadsLatestRequest() throws {
        let store = ActionRequestStore(containerDirectory: directory)
        let request = FinderActionRequest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 10.123),
            context: FinderContext(
                currentDirectory: URL(fileURLWithPath: "/tmp", isDirectory: true),
                selectedItems: []
            )
        )

        try store.write(request)

        XCTAssertEqual(try store.readLatest(), request)
    }

    func testMissingRequestThrowsMalformedRequest() {
        let store = ActionRequestStore(containerDirectory: directory)

        XCTAssertThrowsError(try store.readLatest()) { error in
            XCTAssertEqual(error as? ActionError, .malformedRequest)
        }
    }
}
