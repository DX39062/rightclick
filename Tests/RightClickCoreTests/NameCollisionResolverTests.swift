import Foundation
import XCTest
@testable import RightClickCore

final class NameCollisionResolverTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testUsesBaseNameWhenAvailable() throws {
        let url = try NameCollisionResolver.availableURL(
            directory: directory,
            baseName: "Untitled",
            fileExtension: "txt"
        )

        XCTAssertEqual(url.lastPathComponent, "Untitled.txt")
    }

    func testAppendsNumberWhenNameExists() throws {
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("Untitled.txt").path,
            contents: Data()
        )

        let url = try NameCollisionResolver.availableURL(
            directory: directory,
            baseName: "Untitled",
            fileExtension: "txt"
        )

        XCTAssertEqual(url.lastPathComponent, "Untitled 2.txt")
    }

    func testTrimsWhitespaceAndRejectsEmptyName() {
        XCTAssertThrowsError(
            try NameCollisionResolver.availableURL(directory: directory, baseName: "   ", fileExtension: "txt")
        ) { error in
            XCTAssertEqual(error as? ActionError, .invalidFileName)
        }
    }

    func testRejectsPathSeparatorsInBaseName() {
        XCTAssertThrowsError(
            try NameCollisionResolver.availableURL(directory: directory, baseName: "folder/Untitled", fileExtension: "txt")
        ) { error in
            XCTAssertEqual(error as? ActionError, .invalidFileName)
        }
    }

    func testRejectsNonPositiveRetryLimitWithoutTrapping() {
        XCTAssertThrowsError(
            try NameCollisionResolver.availableURL(
                directory: directory,
                baseName: "Untitled",
                fileExtension: "txt",
                retryLimit: 0
            )
        ) { error in
            XCTAssertEqual(error as? ActionError, .collisionResolutionFailed)
        }
    }
}
