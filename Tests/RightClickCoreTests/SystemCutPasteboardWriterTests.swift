import AppKit
import XCTest
@testable import RightClickCore

final class SystemCutPasteboardWriterTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUpWithError() throws {
        pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
    }

    override func tearDownWithError() throws {
        pasteboard.clearContents()
        pasteboard = nil
    }

    func testWritesCutFileURLsToPasteboard() throws {
        let first = URL(fileURLWithPath: "/tmp/first.txt")
        let second = URL(fileURLWithPath: "/tmp/folder", isDirectory: true)
        let writer = SystemCutPasteboardWriter(pasteboard: pasteboard)

        try writer.write(CutState(itemURLs: [first, second]))

        let objects = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
        XCTAssertEqual(objects, [first, second])
    }

    func testWritesVisibleFileURLTextToPasteboard() throws {
        let first = URL(fileURLWithPath: "/tmp/first.txt")
        let second = URL(fileURLWithPath: "/tmp/folder", isDirectory: true)
        let writer = SystemCutPasteboardWriter(pasteboard: pasteboard)

        try writer.write(CutState(itemURLs: [first, second]))

        XCTAssertEqual(
            pasteboard.string(forType: .string),
            "file:///tmp/first.txt\nfile:///tmp/folder/"
        )
    }
}
