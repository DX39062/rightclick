import XCTest
@testable import RightClickCore

final class TargetDirectoryResolverTests: XCTestCase {
    func testBlankAreaUsesCurrentDirectory() throws {
        let current = URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)
        let context = FinderContext(currentDirectory: current, selectedItems: [])

        XCTAssertEqual(try TargetDirectoryResolver.resolve(context), current)
    }

    func testSingleSelectedFolderCreatesInsideFolder() throws {
        let folder = URL(fileURLWithPath: "/Users/me/Desktop/Folder", isDirectory: true)
        let context = FinderContext(
            currentDirectory: URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true),
            selectedItems: [FinderItem(url: folder, isDirectory: true)]
        )

        XCTAssertEqual(try TargetDirectoryResolver.resolve(context), folder)
    }

    func testSingleSelectedFileCreatesBesideFile() throws {
        let file = URL(fileURLWithPath: "/Users/me/Desktop/report.pdf", isDirectory: false)
        let context = FinderContext(currentDirectory: nil, selectedItems: [FinderItem(url: file, isDirectory: false)])

        XCTAssertEqual(
            try TargetDirectoryResolver.resolve(context),
            URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)
        )
    }

    func testMultipleItemsCreateBesideFirstItemUnlessSingleFolder() throws {
        let file = URL(fileURLWithPath: "/Users/me/Desktop/a.txt", isDirectory: false)
        let folder = URL(fileURLWithPath: "/Users/me/Desktop/Folder", isDirectory: true)
        let context = FinderContext(
            currentDirectory: nil,
            selectedItems: [
                FinderItem(url: file, isDirectory: false),
                FinderItem(url: folder, isDirectory: true)
            ]
        )

        XCTAssertEqual(
            try TargetDirectoryResolver.resolve(context),
            URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)
        )
    }

    func testMissingContextThrows() {
        let context = FinderContext(currentDirectory: nil, selectedItems: [])

        XCTAssertThrowsError(try TargetDirectoryResolver.resolve(context)) { error in
            XCTAssertEqual(error as? ActionError, .missingTargetDirectory)
        }
    }
}
