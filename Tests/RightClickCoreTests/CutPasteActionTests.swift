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

    func testUsesNumberedNamesForSameNamedItemsFromDifferentFolders() throws {
        let otherSource = root.appendingPathComponent("otherSource", isDirectory: true)
        try FileManager.default.createDirectory(at: otherSource, withIntermediateDirectories: true)
        let firstFile = source.appendingPathComponent("note.txt")
        let secondFile = otherSource.appendingPathComponent("note.txt")
        try Data("first".utf8).write(to: firstFile)
        try Data("second".utf8).write(to: secondFile)

        let result = try CutPasteAction().paste(CutState(itemURLs: [firstFile, secondFile]), into: destination)

        let firstDestination = destination.appendingPathComponent("note.txt")
        let secondDestination = destination.appendingPathComponent("note 2.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstDestination.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondDestination.path))
        XCTAssertEqual(result.movedURLs, [firstDestination, secondDestination])
    }

    func testPastingFileIntoCurrentParentIsNoOp() throws {
        let file = source.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)

        let result = try CutPasteAction().paste(CutState(itemURLs: [file]), into: source)

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("note 2.txt").path))
        XCTAssertEqual(result.movedURLs, [file])
    }

    func testPastingFolderIntoCurrentParentIsNoOp() throws {
        let folder = source.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("child.txt"))

        let result = try CutPasteAction().paste(CutState(itemURLs: [folder]), into: source)

        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("child.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("Folder 2").path))
        XCTAssertEqual(result.movedURLs, [folder])
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

    func testNestedSourceSelectionThrowsBeforeMovingAnything() throws {
        let folder = source.appendingPathComponent("Folder", isDirectory: true)
        let child = folder.appendingPathComponent("child.txt")
        let sibling = source.appendingPathComponent("sibling.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("child".utf8).write(to: child)
        try Data("sibling".utf8).write(to: sibling)

        XCTAssertThrowsError(try CutPasteAction().paste(CutState(itemURLs: [sibling, folder, child]), into: destination)) { error in
            XCTAssertEqual(error as? ActionError, .writeFailed("Cannot paste nested cut selections."))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
    }

    func testTargetInsideSelectedFolderThrowsBeforeMovingAnything() throws {
        let folder = source.appendingPathComponent("Parent", isDirectory: true)
        let childTarget = folder.appendingPathComponent("childTarget", isDirectory: true)
        let sibling = source.appendingPathComponent("sibling.txt")
        try FileManager.default.createDirectory(at: childTarget, withIntermediateDirectories: true)
        try Data("sibling".utf8).write(to: sibling)

        XCTAssertThrowsError(try CutPasteAction().paste(CutState(itemURLs: [sibling, folder]), into: childTarget)) { error in
            XCTAssertEqual(error as? ActionError, .writeFailed("Cannot paste a folder into itself."))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: childTarget.appendingPathComponent("sibling.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: childTarget.path))
    }
}
