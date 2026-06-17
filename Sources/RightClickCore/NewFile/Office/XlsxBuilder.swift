import Foundation

public enum XlsxBuilder {
    public static func writeBlankWorkbook(to url: URL) throws {
        throw ActionError.unsupportedFormat("xlsx")
    }
}
