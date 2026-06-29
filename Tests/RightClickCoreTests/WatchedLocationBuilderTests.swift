import XCTest
@testable import RightClickCore

final class WatchedLocationBuilderTests: XCTestCase {
    func testKeepsRootFirstAndRemovesDuplicates() {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let home = URL(fileURLWithPath: "/tmp/rightclick-home", isDirectory: true)

        let urls = WatchedLocationBuilder.build(
            homeDirectory: home,
            rootURL: root,
            existingVolumeURLs: [home, root],
            fileExists: { _ in true }
        )

        XCTAssertEqual(urls.first, root)
        XCTAssertEqual(Set(urls).count, urls.count)
    }

    func testFiltersMissingLocations() {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let home = URL(fileURLWithPath: "/tmp/rightclick-home", isDirectory: true)
        let missingDesktop = home.appendingPathComponent("Desktop", isDirectory: true)

        let urls = WatchedLocationBuilder.build(
            homeDirectory: home,
            rootURL: root,
            existingVolumeURLs: [],
            fileExists: { url in url != missingDesktop }
        )

        XCTAssertFalse(urls.contains(missingDesktop))
        XCTAssertTrue(urls.contains(root))
    }
}
