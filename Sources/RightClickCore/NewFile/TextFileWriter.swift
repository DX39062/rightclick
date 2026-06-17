import Foundation

public enum TextFileWriter {
    public static func writeEmptyFile(to url: URL) throws {
        do {
            try Data().write(to: url, options: .withoutOverwriting)
        } catch {
            throw ActionError.writeFailed(error.localizedDescription)
        }
    }
}
