import Foundation

public struct CutPasteResult: Equatable {
    public let movedURLs: [URL]

    public init(movedURLs: [URL]) {
        self.movedURLs = movedURLs
    }
}

public struct CutPasteAction {
    private let fileManager: FileManager

    private struct MovePlan {
        let source: URL
        let destination: URL
    }

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

        let plan = try makeMovePlan(for: state.itemURLs, into: targetDirectory)

        for move in plan where move.source.standardizedFileURL != move.destination.standardizedFileURL {
            do {
                try fileManager.moveItem(at: move.source, to: move.destination)
            } catch {
                throw ActionError.writeFailed(error.localizedDescription)
            }
        }

        return CutPasteResult(movedURLs: plan.map(\.destination))
    }

    private func makeMovePlan(for sourceURLs: [URL], into targetDirectory: URL) throws -> [MovePlan] {
        for sourceURL in sourceURLs {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw ActionError.sourceItemUnavailable(sourceURL.path)
            }
        }

        guard !hasNestedSelection(sourceURLs) else {
            throw ActionError.writeFailed("Cannot paste nested cut selections.")
        }

        guard !targetDirectoryIsInsideSelectedFolder(sourceURLs, targetDirectory: targetDirectory) else {
            throw ActionError.writeFailed("Cannot paste a folder into itself.")
        }

        let target = targetDirectory.standardizedFileURL
        var plan: [MovePlan] = []
        var reservedDestinations = Set<String>()
        for sourceURL in sourceURLs {
            let source = sourceURL.standardizedFileURL
            let destination: URL
            if source.deletingLastPathComponent().standardizedFileURL == target {
                destination = sourceURL
            } else {
                destination = try availableDestination(
                    for: sourceURL,
                    in: targetDirectory,
                    reservedDestinations: reservedDestinations
                )
            }

            let destinationPath = destination.standardizedFileURL.path
            guard reservedDestinations.insert(destinationPath).inserted else {
                throw ActionError.collisionResolutionFailed
            }

            plan.append(MovePlan(source: sourceURL, destination: destination))
        }

        return plan
    }

    private func availableDestination(
        for sourceURL: URL,
        in targetDirectory: URL,
        reservedDestinations: Set<String>
    ) throws -> URL {
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
            if !fileManager.fileExists(atPath: candidate.path),
               !reservedDestinations.contains(candidate.standardizedFileURL.path) {
                return candidate
            }
        }

        throw ActionError.collisionResolutionFailed
    }

    private func hasNestedSelection(_ sourceURLs: [URL]) -> Bool {
        let componentPaths = sourceURLs.map { $0.standardizedFileURL.pathComponents }
        for sourceIndex in componentPaths.indices {
            for possibleParentIndex in componentPaths.indices where sourceIndex != possibleParentIndex {
                if componentPaths[sourceIndex].starts(with: componentPaths[possibleParentIndex]),
                   componentPaths[sourceIndex].count > componentPaths[possibleParentIndex].count {
                    return true
                }
            }
        }
        return false
    }

    private func targetDirectoryIsInsideSelectedFolder(_ sourceURLs: [URL], targetDirectory: URL) -> Bool {
        let target = targetDirectory.standardizedFileURL
        let targetComponents = target.pathComponents

        for sourceURL in sourceURLs {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let source = sourceURL.standardizedFileURL
            if source.deletingLastPathComponent().standardizedFileURL == target {
                continue
            }

            let sourceComponents = source.pathComponents
            if targetComponents.starts(with: sourceComponents), targetComponents.count >= sourceComponents.count {
                return true
            }
        }

        return false
    }
}
