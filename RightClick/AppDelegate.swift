import AppKit
import RightClickCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func latestTargetDirectory() -> URL {
        let store = ActionRequestStore()
        do {
            let request = try store.readLatest()
            return try TargetDirectoryResolver.resolve(request.context)
        } catch {
            return FileManager.default.homeDirectoryForCurrentUser
        }
    }
}
