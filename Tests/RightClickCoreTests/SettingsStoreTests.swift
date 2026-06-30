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

    func testMigratesLegacySettingsWhenSharedSettingsAreMissing() throws {
        let legacyURL = directory.appendingPathComponent("legacy-settings.json")
        let sharedDirectory = directory.appendingPathComponent("shared", isDirectory: true)
        let legacySettings = AppSettings(isNewFileEnabled: false, isCutPasteEnabled: true)
        try JSONEncoder().encode(legacySettings).write(to: legacyURL)

        let store = SettingsStore(directory: sharedDirectory, legacySettingsURL: legacyURL)

        XCTAssertEqual(try store.load(), legacySettings)
        XCTAssertEqual(try SettingsStore(directory: sharedDirectory).load(), legacySettings)
    }

    func testMainAppUsesFinderExtensionContainerForSharedSettings() {
        let home = URL(fileURLWithPath: "/tmp/rightclick-home", isDirectory: true)
        let appSupport = home.appendingPathComponent("Library/Application Support", isDirectory: true)

        let directory = SettingsStore.defaultDirectory(
            bundleIdentifier: "local.rightclick.RightClick",
            homeDirectory: home,
            applicationSupportDirectory: appSupport
        )

        XCTAssertEqual(
            directory,
            home
                .appendingPathComponent("Library/Containers/local.rightclick.RightClick.FinderExtension/Data/Library/Application Support", isDirectory: true)
                .appendingPathComponent("RightClick", isDirectory: true)
        )
    }

    func testFinderExtensionUsesOwnApplicationSupportDirectory() {
        let home = URL(fileURLWithPath: "/tmp/rightclick-home", isDirectory: true)
        let appSupport = home
            .appendingPathComponent("Library/Containers/local.rightclick.RightClick.FinderExtension/Data/Library/Application Support", isDirectory: true)

        let directory = SettingsStore.defaultDirectory(
            bundleIdentifier: "local.rightclick.RightClick.FinderExtension",
            homeDirectory: home,
            applicationSupportDirectory: appSupport
        )

        XCTAssertEqual(
            directory,
            appSupport.appendingPathComponent("RightClick", isDirectory: true)
        )
    }
}
