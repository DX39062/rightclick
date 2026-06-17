import Foundation

public enum FileFormat: String, CaseIterable, Codable, Equatable, Identifiable {
    case txt
    case docx
    case xlsx
    case pptx
    case py
    case md

    public var id: String { rawValue }

    public static let builtIn: [FileFormat] = [.txt, .docx, .xlsx, .pptx, .py, .md]

    public var fileExtension: String { rawValue }

    public static func parse(_ value: String) throws -> FileFormat {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let format = FileFormat(rawValue: normalized) else {
            throw ActionError.unsupportedFormat(value)
        }
        return format
    }
}
