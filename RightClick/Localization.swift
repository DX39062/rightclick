import Foundation
import RightClickCore

enum L10n {
    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func actionErrorMessage(_ error: Error) -> String {
        guard let actionError = error as? ActionError else {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        switch actionError {
        case .missingTargetDirectory:
            return text("error.missingTargetDirectory")
        case .targetDirectoryUnavailable(let path):
            return String(
                format: text("error.targetDirectoryUnavailable"),
                path
            )
        case .noSelectedItems:
            return text("error.noSelectedItems")
        case .sourceItemUnavailable(let path):
            return String(
                format: text("error.sourceItemUnavailable"),
                path
            )
        case .pasteTargetUnavailable(let path):
            return String(
                format: text("error.pasteTargetUnavailable"),
                path
            )
        case .unsupportedFormat(let value):
            return String(
                format: text("error.unsupportedFormat"),
                value
            )
        case .invalidFileName:
            return text("error.invalidFileName")
        case .collisionResolutionFailed:
            return text("error.collisionResolutionFailed")
        case .writeFailed(let message):
            return String(
                format: text("error.writeFailed"),
                message
            )
        case .malformedRequest:
            return text("error.malformedRequest")
        }
    }
}
