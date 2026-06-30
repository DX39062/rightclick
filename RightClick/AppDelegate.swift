import AppKit
import SwiftUI
import RightClickCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var requestedTargetDirectory: URL?
    private var newFileWindow: NSWindow?
    private var errorWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var didHandleURLAction = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.didHandleURLAction, self.newFileWindow == nil, self.errorWindow == nil else {
                return
            }
            self.showSettingsWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func latestTargetDirectory() -> URL {
        requestedTargetDirectory ?? FileManager.default.homeDirectoryForCurrentUser
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didHandleURLAction = true

        guard let url = urls.first, url.scheme == "rightclick" else {
            return
        }

        guard let route = url.host else {
            showError(ActionError.malformedRequest)
            return
        }

        let request: FinderActionRequest
        do {
            request = try decodeRequest(from: url)
        } catch {
            showError(ActionError.malformedRequest)
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

    private func decodeRequest(from url: URL) throws -> FinderActionRequest {
        guard let requestValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "request" })?
            .value else {
            throw ActionError.malformedRequest
        }

        do {
            return try ActionRequestPayloadCodec.decode(requestValue)
        } catch {
            throw ActionError.malformedRequest
        }
    }

    private func handleNewFile(_ request: FinderActionRequest) {
        do {
            let directory = try TargetDirectoryResolver.resolve(request.context)
            requestedTargetDirectory = directory
            showNewFileWindow(targetDirectory: directory)
        } catch {
            showError(error)
        }
    }

    private func showNewFileWindow(targetDirectory: URL) {
        if let window = newFileWindow {
            NotificationCenter.default.post(
                name: .rightClickTargetDirectoryDidChange,
                object: self,
                userInfo: ["targetDirectory": targetDirectory]
            )
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = L10n.text("newFile.title")
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: NewFileView(
                viewModel: NewFileViewModel(targetDirectory: targetDirectory)
            )
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        newFileWindow = window
    }

    private func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 210),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = L10n.text("settings.title")
        window.delegate = self
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private func handleCut(_ request: FinderActionRequest) {
        guard !request.context.selectedItems.isEmpty else {
            showError(ActionError.noSelectedItems)
            return
        }

        do {
            let state = CutState(itemURLs: request.context.selectedItems.map { $0.url })
            try CutStateStore().save(state)
            do {
                try SystemCutPasteboardWriter().write(state)
            } catch {
                NSLog("RightClick system pasteboard sync failed: \(error.localizedDescription)")
            }
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
        let message = L10n.actionErrorMessage(error)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "RightClick"
        window.delegate = self
        window.contentView = NSHostingView(rootView: ErrorView(message: message))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        errorWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else {
                return
            }

            if window === self.newFileWindow {
                self.newFileWindow = nil
            } else if window === self.errorWindow {
                self.errorWindow = nil
            } else if window === self.settingsWindow {
                self.settingsWindow = nil
            }
        }
    }
}

extension Notification.Name {
    static let rightClickTargetDirectoryDidChange = Notification.Name("RightClickTargetDirectoryDidChange")
}
