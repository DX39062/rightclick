import XCTest
@testable import RightClickCore

final class NewFileActionTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCreatesEmptyTxtFile() throws {
        let action = NewFileAction()

        let result = try action.execute(
            NewFileInput(directory: directory, baseName: "Notes", format: .txt)
        )

        XCTAssertEqual(result.createdURL.lastPathComponent, "Notes.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.createdURL.path))
        XCTAssertEqual(try Data(contentsOf: result.createdURL), Data())
    }

    func testCreatesMarkdownWithCollisionSuffix() throws {
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("Untitled.md").path,
            contents: Data()
        )
        let action = NewFileAction()

        let result = try action.execute(
            NewFileInput(directory: directory, baseName: "Untitled", format: .md)
        )

        XCTAssertEqual(result.createdURL.lastPathComponent, "Untitled 2.md")
    }

    func testRejectsMissingDirectory() {
        let missing = directory.appendingPathComponent("Missing", isDirectory: true)
        let action = NewFileAction()

        XCTAssertThrowsError(
            try action.execute(NewFileInput(directory: missing, baseName: "File", format: .py))
        ) { error in
            XCTAssertEqual(error as? ActionError, .targetDirectoryUnavailable(missing.path))
        }
    }
}
