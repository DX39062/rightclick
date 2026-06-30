import AppKit

public struct SystemCutPasteboardWriter {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func write(_ state: CutState) throws {
        guard !state.itemURLs.isEmpty else {
            throw ActionError.noSelectedItems
        }

        pasteboard.clearContents()
        let didWrite = pasteboard.writeObjects(state.itemURLs as [NSURL])
        guard didWrite else {
            throw ActionError.writeFailed("Failed to write file URLs to the system pasteboard.")
        }

        let visibleText = state.itemURLs
            .map(\.absoluteString)
            .joined(separator: "\n")
        pasteboard.setString(visibleText, forType: .string)
    }
}
