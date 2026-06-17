import Foundation

public enum NameCollisionResolver {
    public static func availableURL(
        directory: URL,
        baseName: String,
        fileExtension: String,
        fileManager: FileManager = .default,
        retryLimit: Int = 500
    ) throws -> URL {
        let cleanBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBaseName.isEmpty else {
            throw ActionError.invalidFileName
        }

        for index in 1...retryLimit {
            let suffix = index == 1 ? "" : " \(index)"
            let candidate = directory.appendingPathComponent("\(cleanBaseName)\(suffix).\(fileExtension)")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw ActionError.collisionResolutionFailed
    }
}
