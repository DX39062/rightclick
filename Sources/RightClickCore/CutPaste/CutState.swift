import Foundation

public struct CutState: Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let itemURLs: [URL]

    public init(id: UUID = UUID(), createdAt: Date = Date(), itemURLs: [URL]) {
        self.id = id
        self.createdAt = createdAt
        self.itemURLs = itemURLs
    }
}
