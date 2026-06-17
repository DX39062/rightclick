import Foundation

public enum DocxBuilder {
    public static func writeBlankDocument(to url: URL) throws {
        throw ActionError.unsupportedFormat("docx")
    }
}
