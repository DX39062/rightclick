import XCTest
@testable import RightClickCore

final class CutPasteActionTests: XCTestCase {
    private var root: URL!
    private var source: URL!
    private var destination: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        source = root.appendingPathComponent("source", isDirectory: true)
        destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testMovesFileIntoDestination() throws {
        let file = source.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)

        let result = try CutPasteAction().paste(CutState(itemURLs: [file]), into: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("note.txt").path))
        XCTAssertEqual(result.movedURLs, [destination.appendingPathComponent("note.txt")])
    }

    func testMovesFolderIntoDestination() throws {
        let folder = source.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("child.txt"))

        let result = try CutPasteAction().paste(CutState(itemURLs: [folder]), into: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Folder/child.txt").path))
        XCTAssertEqual(result.movedURLs, [destination.appendingPathComponent("Folder", isDirectory: true)])
    }

    func testUsesNumberedNameWhenDestinationExists() throws {
        let file = source.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)
        try Data("existing".utf8).write(to: destination.appendingPathComponent("note.txt"))

        let result = try CutPasteAction().paste(CutState(itemURLs: [file]), into: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("note 2.txt").path))
        XCTAssertEqual(result.movedURLs, [destination.appendingPathComponent("note 2.txt")])
    }

    func testMissingSourceThrowsAndDoesNotMoveOtherItems() throws {
        let missing = source.appendingPathComponent("missing.txt")
        let existing = source.appendingPathComponent("existing.txt")
        try Data().write(to: existing)

        XCTAssertThrowsError(try CutPasteAction().paste(CutState(itemURLs: [missing, existing]), into: destination)) { error in
            XCTAssertEqual(error as? ActionError, .sourceItemUnavailable(missing.path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: existing.path))
    }
}
