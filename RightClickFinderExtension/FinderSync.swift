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

        openMainApp(request: request)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private func openMainApp(request: FinderActionRequest) {
        do {
            var components = URLComponents()
            components.scheme = "rightclick"
            components.host = "new-file"
            components.queryItems = [
                URLQueryItem(name: "request", value: try ActionRequestPayloadCodec.encode(request))
            ]

            guard let url = components.url else {
                NSLog("RightClick request URL could not be built")
                return
            }

            NSWorkspace.shared.open(url)
        } catch {
            NSLog("RightClick Finder request failed: \(error.localizedDescription)")
            return
        }
    }
}
