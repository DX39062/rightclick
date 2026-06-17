import Foundation

public struct NewFileInput: Equatable {
    public let directory: URL
    public let baseName: String
    public let format: FileFormat

    public init(directory: URL, baseName: String, format: FileFormat) {
        self.directory = directory
        self.baseName = baseName
        self.format = format
    }
}

public struct NewFileAction: ActionExecutor {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func execute(_ input: NewFileInput) throws -> ActionResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: input.directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ActionError.targetDirectoryUnavailable(input.directory.path)
        }

        let destination = try NameCollisionResolver.availableURL(
            directory: input.directory,
            baseName: input.baseName,
            fileExtension: input.format.fileExtension,
            fileManager: fileManager
        )

        switch input.format {
        case .txt, .md, .py:
            try TextFileWriter.writeEmptyFile(to: destination)
        case .docx:
            try DocxBuilder.writeBlankDocument(to: destination)
        case .xlsx:
            try XlsxBuilder.writeBlankWorkbook(to: destination)
        case .pptx:
            try PptxBuilder.writeBlankPresentation(to: destination)
        }

        return ActionResult(createdURL: destination)
    }
}
