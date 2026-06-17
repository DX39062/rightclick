import XCTest
@testable import RightClickCore

final class SmokeTests: XCTestCase {
    func testFinderContextStoresCurrentDirectory() {
        let url = URL(fileURLWithPath: "/tmp/example", isDirectory: true)
        let context = FinderContext(currentDirectory: url, selectedItems: [])

        XCTAssertEqual(context.currentDirectory, url)
        XCTAssertTrue(context.selectedItems.isEmpty)
    }
}
