import Foundation

enum AppGroup {
    static let identifier = "group.local.rightclick"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("RightClick", isDirectory: true)
        }
        return url
    }
}
