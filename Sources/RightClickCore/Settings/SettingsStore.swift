import Foundation

public struct SettingsStore {
    public static let appSupportDirectoryName = "RightClick"
    public static let fileName = "settings.json"
    public static let appBundleIdentifier = "local.rightclick.RightClick"
    public static let finderExtensionBundleIdentifier = "local.rightclick.RightClick.FinderExtension"

    public let directory: URL
    private let legacySettingsURL: URL?

    public init() {
        self.directory = SettingsStore.defaultDirectory()
        self.legacySettingsURL = SettingsStore.defaultLegacySettingsURL()
    }

    public init(directory: URL, legacySettingsURL: URL? = nil) {
        self.directory = directory
        self.legacySettingsURL = legacySettingsURL
    }

    public static func defaultDirectory(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationSupportDirectory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ) -> URL {
        let base = sharedApplicationSupportDirectory(
            bundleIdentifier: bundleIdentifier,
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory
        )
        return base.appendingPathComponent(appSupportDirectoryName, isDirectory: true)
    }

    private static func sharedApplicationSupportDirectory(
        bundleIdentifier: String?,
        homeDirectory: URL,
        applicationSupportDirectory: URL?
    ) -> URL {
        if bundleIdentifier == appBundleIdentifier {
            return homeDirectory
                .appendingPathComponent("Library/Containers", isDirectory: true)
                .appendingPathComponent(finderExtensionBundleIdentifier, isDirectory: true)
                .appendingPathComponent("Data/Library/Application Support", isDirectory: true)
        }

        return applicationSupportDirectory
            ?? homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    public var settingsURL: URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            if let migrated = try migrateLegacySettingsIfAvailable() {
                return migrated
            }
            return .default
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: [.atomic])
    }

    public static func defaultLegacySettingsURL(
        applicationSupportDirectory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ) -> URL? {
        applicationSupportDirectory?
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private func migrateLegacySettingsIfAvailable() throws -> AppSettings? {
        guard let legacySettingsURL, legacySettingsURL != settingsURL else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: legacySettingsURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: legacySettingsURL)
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            try save(settings)
            return settings
        } catch {
            return nil
        }
    }
}
