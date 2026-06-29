import Foundation

public struct CutStateStore {
    public static let fileName = "cut-state.json"

    public let directory: URL

    public init(directory: URL = SettingsStore.defaultDirectory) {
        self.directory = directory
    }

    public var stateURL: URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public func load() throws -> CutState? {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: stateURL)
            return try JSONDecoder().decode(CutState.self, from: data)
        } catch {
            return nil
        }
    }

    public func save(_ state: CutState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateURL, options: [.atomic])
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: stateURL)
    }
}
