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

    func testDefaultContainerDirectoryUsesApplicationSupport() {
        let directory = ActionRequestStore.defaultContainerDirectory

        XCTAssertEqual(directory.lastPathComponent, ActionRequestStore.defaultDirectoryName)
        XCTAssertTrue(directory.deletingLastPathComponent().path.hasSuffix("Application Support"))
    }

    func testPayloadCodecRoundTripsRequestForURLTransport() throws {
        let request = FinderActionRequest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            createdAt: Date(timeIntervalSince1970: 20.456),
            context: FinderContext(
                currentDirectory: URL(fileURLWithPath: "/tmp", isDirectory: true),
                selectedItems: [
                    FinderItem(url: URL(fileURLWithPath: "/tmp/example.txt"), isDirectory: false)
                ]
            )
        )

        let encoded = try ActionRequestPayloadCodec.encode(request)
        XCTAssertFalse(encoded.contains("="))

        XCTAssertEqual(try ActionRequestPayloadCodec.decode(encoded), request)
    }

    func testReadsLegacyRequestWithoutFractionalSeconds() throws {
        let store = ActionRequestStore(containerDirectory: directory)
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "createdAt": "1970-01-01T00:00:10Z",
          "context": {
            "currentDirectory": "file:///tmp/",
            "selectedItems": []
          }
        }
        """
        try json.data(using: .utf8)!.write(
            to: directory.appendingPathComponent(ActionRequestStore.defaultFileName)
        )

        let request = try store.readLatest()

        XCTAssertEqual(request.createdAt, Date(timeIntervalSince1970: 10))
    }
}
