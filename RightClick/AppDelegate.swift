import AppKit
import RightClickCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var requestedTargetDirectory: URL?

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
              url.host == "new-file",
              let requestValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "request" })?
                .value else {
            return
        }

        do {
            let request = try ActionRequestPayloadCodec.decode(requestValue)
            let directory = try TargetDirectoryResolver.resolve(request.context)
            requestedTargetDirectory = directory
            NotificationCenter.default.post(
                name: .rightClickTargetDirectoryDidChange,
                object: self,
                userInfo: ["targetDirectory": directory]
            )
        } catch {
            NSLog("RightClick request URL failed: \(error.localizedDescription)")
        }
    }
}

extension Notification.Name {
    static let rightClickTargetDirectoryDidChange = Notification.Name("RightClickTargetDirectoryDidChange")
}
