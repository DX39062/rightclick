import Foundation

public enum TargetDirectoryResolver {
    public static func resolve(_ context: FinderContext) throws -> URL {
        if context.selectedItems.isEmpty {
            guard let currentDirectory = context.currentDirectory else {
                throw ActionError.missingTargetDirectory
            }
            return currentDirectory
        }

        if context.selectedItems.count == 1 {
            let item = context.selectedItems[0]
            return item.isDirectory ? item.url : item.url.deletingLastPathComponent()
        }

        let first = context.selectedItems[0]
        return first.url.deletingLastPathComponent()
    }
}
