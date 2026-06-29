import AppKit
import SwiftUI
import RightClickCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var requestedTargetDirectory: URL?
    private var errorWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func latestTargetDirectory() -> URL {
        requestedTargetDirectory ?? FileManager.default.homeDirectoryForCurrentUser
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme == "rightclick",
              let route = url.host,
              let request = decodeRequest(from: url) else {
            return
        }

        switch route {
        case "new-file":
            handleNewFile(request)
        case "cut":
            handleCut(request)
        case "paste":
            handlePaste(request)
        default:
            return
        }
    }

    private func decodeRequest(from url: URL) -> FinderActionRequest? {
        guard let requestValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "request" })?
            .value else {
            return nil
        }
        return try? ActionRequestPayloadCodec.decode(requestValue)
    }

    private func handleNewFile(_ request: FinderActionRequest) {
        do {
            let directory = try TargetDirectoryResolver.resolve(request.context)
            requestedTargetDirectory = directory
            NotificationCenter.default.post(
                name: .rightClickTargetDirectoryDidChange,
                object: self,
                userInfo: ["targetDirectory": directory]
            )
        } catch {
            showError(error)
        }
    }

    private func handleCut(_ request: FinderActionRequest) {
        guard !request.context.selectedItems.isEmpty else {
            showError(ActionError.noSelectedItems)
            return
        }

        do {
            let state = CutState(itemURLs: request.context.selectedItems.map { $0.url })
            try CutStateStore().save(state)
            NSApp.terminate(nil)
        } catch {
            showError(error)
        }
    }

    private func handlePaste(_ request: FinderActionRequest) {
        do {
            guard let state = try CutStateStore().load() else {
                throw ActionError.malformedRequest
            }
            let targetDirectory = try TargetDirectoryResolver.resolve(request.context)
            let result = try CutPasteAction().paste(state, into: targetDirectory)
            try CutStateStore().clear()
            NSWorkspace.shared.activateFileViewerSelecting(result.movedURLs)
            NSApp.terminate(nil)
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "RightClick"
        window.contentView = NSHostingView(rootView: ErrorView(message: message))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        errorWindow = window
    }
}

extension Notification.Name {
    static let rightClickTargetDirectoryDidChange = Notification.Name("RightClickTargetDirectoryDidChange")
}
