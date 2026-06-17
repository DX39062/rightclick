import Foundation

public enum PptxBuilder {
    public static func writeBlankPresentation(to url: URL) throws {
        throw ActionError.unsupportedFormat("pptx")
    }
}
