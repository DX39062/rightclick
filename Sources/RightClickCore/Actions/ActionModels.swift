import Foundation

public enum ActionError: Error, Equatable, LocalizedError {
    case missingTargetDirectory
    case targetDirectoryUnavailable(String)
    case unsupportedFormat(String)
    case invalidFileName
    case collisionResolutionFailed
    case writeFailed(String)
    case malformedRequest

    public var errorDescription: String? {
        switch self {
        case .missingTargetDirectory:
            return "No target directory was provided."
        case .targetDirectoryUnavailable(let path):
            return "The target directory is unavailable: \(path)"
        case .unsupportedFormat(let value):
            return "Unsupported file format: \(value)"
        case .invalidFileName:
            return "The file name is invalid."
        case .collisionResolutionFailed:
            return "Could not find an available file name."
        case .writeFailed(let message):
            return "File creation failed: \(message)"
        case .malformedRequest:
            return "The Finder action request is malformed."
        }
    }
}

public struct ActionResult: Equatable {
    public let createdURL: URL

    public init(createdURL: URL) {
        self.createdURL = createdURL
    }
}

public protocol ActionExecutor {
    associatedtype Input
    func execute(_ input: Input) throws -> ActionResult
}
