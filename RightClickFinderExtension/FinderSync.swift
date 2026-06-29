import Cocoa
import FinderSync
import RightClickCore

final class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [FileManager.default.homeDirectoryForCurrentUser]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: "New File...", action: #selector(openNewFileWindow(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openNewFileWindow(_ sender: Any?) {
        let controller = FIFinderSyncController.default()
        let selectedURLs = controller.selectedItemURLs() ?? []
        let currentDirectory = controller.targetedURL()

        let items = selectedURLs.map { url in
            FinderItem(url: url, isDirectory: isDirectory(url))
        }
        let context = FinderContext(currentDirectory: currentDirectory, selectedItems: items)
        let request = FinderActionRequest(context: context)

        do {
            let store = ActionRequestStore()
            try store.write(request)
            openMainApp()
        } catch {
            NSLog("RightClick Finder request failed: \(error.localizedDescription)")
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private func openMainApp() {
        let bundleIdentifier = "local.rightclick.RightClick"
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            NSLog("RightClick app not found for bundle identifier: \(bundleIdentifier)")
            return
        }

        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                NSLog("RightClick app launch failed: \(error.localizedDescription)")
            }
        }
    }
}
