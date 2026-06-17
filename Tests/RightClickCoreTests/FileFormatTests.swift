import Foundation
import XCTest
@testable import RightClickCore

final class FileFormatTests: XCTestCase {
    func testBuiltInFormatsAreInDisplayOrder() {
        XCTAssertEqual(FileFormat.builtIn.map(\.rawValue), ["txt", "docx", "xlsx", "pptx", "py", "md"])
    }

    func testExtensionValues() throws {
        XCTAssertEqual(try FileFormat.parse("txt").fileExtension, "txt")
        XCTAssertEqual(try FileFormat.parse("DOCX").fileExtension, "docx")
        XCTAssertEqual(try FileFormat.parse("md").fileExtension, "md")
    }

    func testUnsupportedFormatThrows() {
        XCTAssertThrowsError(try FileFormat.parse("pdf")) { error in
            XCTAssertEqual(error as? ActionError, .unsupportedFormat("pdf"))
        }
    }
}
