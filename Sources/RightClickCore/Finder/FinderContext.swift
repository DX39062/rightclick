import Foundation

public struct FinderItem: Equatable, Codable {
    public let url: URL
    public let isDirectory: Bool

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }
}

public struct FinderContext: Equatable, Codable {
    public let currentDirectory: URL?
    public let selectedItems: [FinderItem]

    public init(currentDirectory: URL?, selectedItems: [FinderItem]) {
        self.currentDirectory = currentDirectory
        self.selectedItems = selectedItems
    }
}
