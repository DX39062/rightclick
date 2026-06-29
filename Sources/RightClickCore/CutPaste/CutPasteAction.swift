import Foundation

public struct CutPasteResult: Equatable {
    public let movedURLs: [URL]

    public init(movedURLs: [URL]) {
        self.movedURLs = movedURLs
    }
}

public struct CutPasteAction {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func paste(_ state: CutState, into targetDirectory: URL) throws -> CutPasteResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: targetDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ActionError.pasteTargetUnavailable(targetDirectory.path)
        }

        guard !state.itemURLs.isEmpty else {
            throw ActionError.noSelectedItems
        }

        for sourceURL in state.itemURLs {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw ActionError.sourceItemUnavailable(sourceURL.path)
            }
        }

        var movedURLs: [URL] = []
        for sourceURL in state.itemURLs {
            let destination = try availableDestination(for: sourceURL, in: targetDirectory)
            do {
                try fileManager.moveItem(at: sourceURL, to: destination)
            } catch {
                throw ActionError.writeFailed(error.localizedDescription)
            }
            movedURLs.append(destination)
        }

        return CutPasteResult(movedURLs: movedURLs)
    }

    private func availableDestination(for sourceURL: URL, in targetDirectory: URL) throws -> URL {
        let lastPathComponent = sourceURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lastPathComponent.isEmpty, lastPathComponent == (lastPathComponent as NSString).lastPathComponent else {
            throw ActionError.invalidFileName
        }

        let pathExtension = sourceURL.pathExtension
        let baseName = pathExtension.isEmpty
            ? lastPathComponent
            : sourceURL.deletingPathExtension().lastPathComponent

        for index in 1...500 {
            let suffix = index == 1 ? "" : " \(index)"
            let candidateName = pathExtension.isEmpty
                ? "\(baseName)\(suffix)"
                : "\(baseName)\(suffix).\(pathExtension)"
            let candidate = targetDirectory.appendingPathComponent(candidateName, isDirectory: sourceURL.hasDirectoryPath)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw ActionError.collisionResolutionFailed
    }
}
