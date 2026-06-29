import XCTest
@testable import RightClickCore

final class SettingsStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingSettingsReturnsDefaultSettings() throws {
        let store = SettingsStore(directory: directory)
        XCTAssertEqual(try store.load(), AppSettings.default)
    }

    func testSavesAndLoadsSettings() throws {
        let store = SettingsStore(directory: directory)
        let settings = AppSettings(isNewFileEnabled: false, isCutPasteEnabled: true)

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)
    }

    func testMalformedSettingsReturnsDefaultSettings() throws {
        let store = SettingsStore(directory: directory)
        try "{not-json".write(to: store.settingsURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(try store.load(), AppSettings.default)
    }
}
