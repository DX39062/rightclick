import Cocoa
import FinderSync
import RightClickCore

final class FinderSync: FIFinderSync {
    private let settingsStore = SettingsStore()
    private let cutStateStore = CutStateStore()

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = Set(WatchedLocationBuilder.build())
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let settings = (try? settingsStore.load()) ?? .default
        let menu = NSMenu(title: "")
        let controller = FIFinderSyncController.default()
        let selectedURLs = controller.selectedItemURLs() ?? []
        let hasCutState = ((try? cutStateStore.load()) ?? nil) != nil

        if settings.isNewFileEnabled {
            let item = NSMenuItem(title: String(localized: "menu.newFile"), action: #selector(openNewFileWindow(_:)), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        if settings.isCutPasteEnabled {
            if !selectedURLs.isEmpty {
                let item = NSMenuItem(title: String(localized: "menu.cut"), action: #selector(cutSelectedItems(_:)), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }

            if hasCutState {
                let item = NSMenuItem(title: String(localized: "menu.paste"), action: #selector(pasteCutItems(_:)), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
        }

        return menu
    }

    @objc private func openNewFileWindow(_ sender: Any?) {
        openMainApp(route: "new-file")
    }

    @objc private func cutSelectedItems(_ sender: Any?) {
        openMainApp(route: "cut")
    }

    @objc private func pasteCutItems(_ sender: Any?) {
        openMainApp(route: "paste")
    }

    private func openMainApp(route: String) {
        let controller = FIFinderSyncController.default()
        let selectedURLs = controller.selectedItemURLs() ?? []
        let currentDirectory = controller.targetedURL()

        let items = selectedURLs.map { url in
            FinderItem(url: url, isDirectory: isDirectory(url))
        }
        let context = FinderContext(currentDirectory: currentDirectory, selectedItems: items)
        let request = FinderActionRequest(context: context)

        do {
            var components = URLComponents()
            components.scheme = "rightclick"
            components.host = route
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
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}
