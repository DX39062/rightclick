import Foundation

public struct AppSettings: Codable, Equatable {
    public var isNewFileEnabled: Bool
    public var isCutPasteEnabled: Bool

    public static let `default` = AppSettings(
        isNewFileEnabled: true,
        isCutPasteEnabled: false
    )

    public init(isNewFileEnabled: Bool, isCutPasteEnabled: Bool) {
        self.isNewFileEnabled = isNewFileEnabled
        self.isCutPasteEnabled = isCutPasteEnabled
    }
}
