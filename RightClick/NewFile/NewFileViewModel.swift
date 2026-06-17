import Foundation
import AppKit
import RightClickCore

@MainActor
final class NewFileViewModel: ObservableObject {
    @Published var baseName: String
    @Published var selectedFormat: FileFormat
    @Published var targetDirectory: URL
    @Published var errorMessage: String?

    private let action: NewFileAction

    init(
        baseName: String = "Untitled",
        selectedFormat: FileFormat = .txt,
        targetDirectory: URL,
        action: NewFileAction = NewFileAction()
    ) {
        self.baseName = baseName
        self.selectedFormat = selectedFormat
        self.targetDirectory = targetDirectory
        self.action = action
    }

    static func preview() -> NewFileViewModel {
        NewFileViewModel(targetDirectory: FileManager.default.homeDirectoryForCurrentUser)
    }

    func create() {
        do {
            let result = try action.execute(
                NewFileInput(directory: targetDirectory, baseName: baseName, format: selectedFormat)
            )
            NSWorkspace.shared.activateFileViewerSelecting([result.createdURL])
            NSApp.keyWindow?.close()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
