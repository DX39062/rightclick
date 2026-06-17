import XCTest
import ZIPFoundation
@testable import RightClickCore

final class OfficeBuilderTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testDocxContainsRequiredEntries() throws {
        let url = directory.appendingPathComponent("Blank.docx")
        try DocxBuilder.writeBlankDocument(to: url)

        let names = try archiveEntryNames(url)
        XCTAssertTrue(names.contains("[Content_Types].xml"))
        XCTAssertTrue(names.contains("_rels/.rels"))
        XCTAssertTrue(names.contains("word/document.xml"))
        XCTAssertTrue(names.contains("word/_rels/document.xml.rels"))
    }

    func testXlsxContainsRequiredEntries() throws {
        let url = directory.appendingPathComponent("Blank.xlsx")
        try XlsxBuilder.writeBlankWorkbook(to: url)

        let names = try archiveEntryNames(url)
        XCTAssertTrue(names.contains("[Content_Types].xml"))
        XCTAssertTrue(names.contains("_rels/.rels"))
        XCTAssertTrue(names.contains("xl/workbook.xml"))
        XCTAssertTrue(names.contains("xl/worksheets/sheet1.xml"))
    }

    func testPptxContainsRequiredEntries() throws {
        let url = directory.appendingPathComponent("Blank.pptx")
        try PptxBuilder.writeBlankPresentation(to: url)

        let names = try archiveEntryNames(url)
        XCTAssertTrue(names.contains("[Content_Types].xml"))
        XCTAssertTrue(names.contains("_rels/.rels"))
        XCTAssertTrue(names.contains("ppt/presentation.xml"))
        XCTAssertTrue(names.contains("ppt/slides/slide1.xml"))
    }

    private func archiveEntryNames(_ url: URL) throws -> Set<String> {
        guard let archive = Archive(url: url, accessMode: .read) else {
            XCTFail("Expected readable ZIP archive at \(url.path)")
            return []
        }

        return Set(archive.map(\.path))
    }
}
