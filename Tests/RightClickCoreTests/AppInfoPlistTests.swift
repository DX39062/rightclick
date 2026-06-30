import XCTest

final class AppInfoPlistTests: XCTestCase {
    func testMainAppRunsAsAgentWithoutDockIcon() throws {
        let plistURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("RightClick/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
    }
}
