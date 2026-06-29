# Finder Cut Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable Finder actions, broaden Finder Sync watched locations, and implement Windows-style Cut/Paste file moves.

**Architecture:** Shared state and action logic live in `RightClickCore` so both the app and Finder extension use the same settings, cut-state, watched-location, and move behavior. The Finder extension stays thin: it reads settings, builds native menu items, captures Finder context, and opens `rightclick://` routes. The main app owns settings UI, action execution, user-visible errors, and quitting helper windows after non-UI actions.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, FinderSync, XCTest, local JSON files under `~/Library/Application Support/RightClick`.

---

## File Structure

- Create `Sources/RightClickCore/Settings/AppSettings.swift`: settings model and defaults.
- Create `Sources/RightClickCore/Settings/SettingsStore.swift`: JSON persistence for settings.
- Create `Sources/RightClickCore/CutPaste/CutState.swift`: stored cut operation model.
- Create `Sources/RightClickCore/CutPaste/CutStateStore.swift`: JSON persistence for cut state.
- Create `Sources/RightClickCore/CutPaste/CutPasteAction.swift`: move selected items into the paste target.
- Create `Sources/RightClickCore/Finder/WatchedLocationBuilder.swift`: builds Finder Sync watched directories.
- Modify `Sources/RightClickCore/Actions/ActionModels.swift`: add cut/paste specific errors.
- Modify `RightClickFinderExtension/FinderSync.swift`: build menu from settings and route new actions.
- Modify `RightClick/AppDelegate.swift`: route `new-file`, `cut`, and `paste`.
- Modify `RightClick/RightClickApp.swift`: add settings scene.
- Create `RightClick/Settings/SettingsView.swift`: toggles and restart Finder command.
- Create `RightClick/Error/ErrorView.swift`: compact error window for failed non-UI actions.
- Modify `RightClick.xcodeproj/project.pbxproj`: add new app Swift files to the `RightClick` target sources.
- Modify `README.md`: document settings, cut/paste, watched-location caveats, and update flow.
- Add focused XCTest files under `Tests/RightClickCoreTests`.

## Task 1: Settings Model And Store

**Files:**
- Create: `Sources/RightClickCore/Settings/AppSettings.swift`
- Create: `Sources/RightClickCore/Settings/SettingsStore.swift`
- Test: `Tests/RightClickCoreTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/RightClickCoreTests/SettingsStoreTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class SettingsStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingSettingsReturnsDefaultSettings() throws {
        let store = SettingsStore(directory: directory)
        XCTAssertEqual(try store.load(), AppSettings.default)
    }

    func testSavesAndLoadsSettings() throws {
        let store = SettingsStore(directory: directory)
        let settings = AppSettings(isNewFileEnabled: false, isCutPasteEnabled: true)

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)
    }

    func testMalformedSettingsReturnsDefaultSettings() throws {
        let store = SettingsStore(directory: directory)
        try "{not-json".write(to: store.settingsURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(try store.load(), AppSettings.default)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter SettingsStoreTests
```

Expected: fails because `SettingsStore` and `AppSettings` do not exist.

- [ ] **Step 3: Add settings model**

Create `Sources/RightClickCore/Settings/AppSettings.swift`:

```swift
import Foundation

public struct AppSettings: Codable, Equatable {
    public var isNewFileEnabled: Bool
    public var isCutPasteEnabled: Bool

    public static let `default` = AppSettings(
        isNewFileEnabled: true,
        isCutPasteEnabled: false
    )

    public init(isNewFileEnabled: Bool, isCutPasteEnabled: Bool) {
        self.isNewFileEnabled = isNewFileEnabled
        self.isCutPasteEnabled = isCutPasteEnabled
    }
}
```

- [ ] **Step 4: Add settings store**

Create `Sources/RightClickCore/Settings/SettingsStore.swift`:

```swift
import Foundation

public struct SettingsStore {
    public static let appSupportDirectoryName = "RightClick"
    public static let fileName = "settings.json"

    public let directory: URL

    public init(directory: URL = SettingsStore.defaultDirectory) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent(appSupportDirectoryName, isDirectory: true)
    }

    public var settingsURL: URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.rightClick.encode(settings)
        try data.write(to: settingsURL, options: [.atomic])
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter SettingsStoreTests
```

Expected: all `SettingsStoreTests` pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/RightClickCore/Settings Tests/RightClickCoreTests/SettingsStoreTests.swift
git commit -m "feat: add app settings store"
```

## Task 2: Watched Location Builder

**Files:**
- Create: `Sources/RightClickCore/Finder/WatchedLocationBuilder.swift`
- Test: `Tests/RightClickCoreTests/WatchedLocationBuilderTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/RightClickCoreTests/WatchedLocationBuilderTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class WatchedLocationBuilderTests: XCTestCase {
    func testKeepsRootFirstAndRemovesDuplicates() {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let home = URL(fileURLWithPath: "/tmp/rightclick-home", isDirectory: true)

        let urls = WatchedLocationBuilder.build(
            homeDirectory: home,
            rootURL: root,
            existingVolumeURLs: [home, root],
            fileExists: { _ in true }
        )

        XCTAssertEqual(urls.first, root)
        XCTAssertEqual(Set(urls).count, urls.count)
    }

    func testFiltersMissingLocations() {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let home = URL(fileURLWithPath: "/tmp/rightclick-home", isDirectory: true)
        let missingDesktop = home.appendingPathComponent("Desktop", isDirectory: true)

        let urls = WatchedLocationBuilder.build(
            homeDirectory: home,
            rootURL: root,
            existingVolumeURLs: [],
            fileExists: { url in url != missingDesktop }
        )

        XCTAssertFalse(urls.contains(missingDesktop))
        XCTAssertTrue(urls.contains(root))
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter WatchedLocationBuilderTests
```

Expected: fails because `WatchedLocationBuilder` does not exist.

- [ ] **Step 3: Add builder**

Create `Sources/RightClickCore/Finder/WatchedLocationBuilder.swift`:

```swift
import Foundation

public enum WatchedLocationBuilder {
    public static func build(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        rootURL: URL = URL(fileURLWithPath: "/", isDirectory: true),
        existingVolumeURLs: [URL] = mountedVolumeRoots(),
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> [URL] {
        var ordered: [URL] = [
            rootURL,
            homeDirectory,
            homeDirectory.appendingPathComponent("Desktop", isDirectory: true),
            homeDirectory.appendingPathComponent("Documents", isDirectory: true),
            homeDirectory.appendingPathComponent("Downloads", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/Mobile Documents", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/CloudStorage", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true)
        ]
        ordered.append(contentsOf: existingVolumeURLs)

        var seen = Set<URL>()
        var result: [URL] = []

        for url in ordered {
            let normalized = url.standardizedFileURL
            guard !seen.contains(normalized), fileExists(normalized) else {
                continue
            }
            seen.insert(normalized)
            result.append(normalized)
        }

        return result
    }

    private static func mountedVolumeRoots() -> [URL] {
        let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumes,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter WatchedLocationBuilderTests
```

Expected: all watched-location tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/RightClickCore/Finder/WatchedLocationBuilder.swift Tests/RightClickCoreTests/WatchedLocationBuilderTests.swift
git commit -m "feat: build Finder watched locations"
```

## Task 3: Cut State Store

**Files:**
- Create: `Sources/RightClickCore/CutPaste/CutState.swift`
- Create: `Sources/RightClickCore/CutPaste/CutStateStore.swift`
- Test: `Tests/RightClickCoreTests/CutStateStoreTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/RightClickCoreTests/CutStateStoreTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class CutStateStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingStateReturnsNil() throws {
        let store = CutStateStore(directory: directory)
        XCTAssertNil(try store.load())
    }

    func testSavesAndLoadsState() throws {
        let store = CutStateStore(directory: directory)
        let state = CutState(itemURLs: [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/folder", isDirectory: true)
        ])

        try store.save(state)

        XCTAssertEqual(try store.load(), state)
    }

    func testClearRemovesState() throws {
        let store = CutStateStore(directory: directory)
        try store.save(CutState(itemURLs: [URL(fileURLWithPath: "/tmp/a.txt")]))

        try store.clear()

        XCTAssertNil(try store.load())
    }

    func testMalformedStateReturnsNil() throws {
        let store = CutStateStore(directory: directory)
        try "{not-json".write(to: store.stateURL, atomically: true, encoding: .utf8)

        XCTAssertNil(try store.load())
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter CutStateStoreTests
```

Expected: fails because `CutState` and `CutStateStore` do not exist.

- [ ] **Step 3: Add cut state model**

Create `Sources/RightClickCore/CutPaste/CutState.swift`:

```swift
import Foundation

public struct CutState: Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let itemURLs: [URL]

    public init(id: UUID = UUID(), createdAt: Date = Date(), itemURLs: [URL]) {
        self.id = id
        self.createdAt = createdAt
        self.itemURLs = itemURLs
    }
}
```

- [ ] **Step 4: Add cut state store**

Create `Sources/RightClickCore/CutPaste/CutStateStore.swift`:

```swift
import Foundation

public struct CutStateStore {
    public static let fileName = "cut-state.json"

    public let directory: URL

    public init(directory: URL = SettingsStore.defaultDirectory) {
        self.directory = directory
    }

    public var stateURL: URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public func load() throws -> CutState? {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: stateURL)
            return try JSONDecoder.rightClick.decode(CutState.self, from: data)
        } catch {
            return nil
        }
    }

    public func save(_ state: CutState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.rightClick.encode(state)
        try data.write(to: stateURL, options: [.atomic])
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: stateURL)
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter CutStateStoreTests
```

Expected: all cut-state store tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/RightClickCore/CutPaste Tests/RightClickCoreTests/CutStateStoreTests.swift
git commit -m "feat: store Finder cut state"
```

## Task 4: Cut And Paste Move Action

**Files:**
- Modify: `Sources/RightClickCore/Actions/ActionModels.swift`
- Create: `Sources/RightClickCore/CutPaste/CutPasteAction.swift`
- Test: `Tests/RightClickCoreTests/CutPasteActionTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/RightClickCoreTests/CutPasteActionTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class CutPasteActionTests: XCTestCase {
    private var root: URL!
    private var source: URL!
    private var destination: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        source = root.appendingPathComponent("source", isDirectory: true)
        destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testMovesFileIntoDestination() throws {
        let file = source.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)

        let result = try CutPasteAction().paste(CutState(itemURLs: [file]), into: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("note.txt").path))
        XCTAssertEqual(result.movedURLs, [destination.appendingPathComponent("note.txt")])
    }

    func testMovesFolderIntoDestination() throws {
        let folder = source.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("child.txt"))

        let result = try CutPasteAction().paste(CutState(itemURLs: [folder]), into: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Folder/child.txt").path))
        XCTAssertEqual(result.movedURLs, [destination.appendingPathComponent("Folder", isDirectory: true)])
    }

    func testUsesNumberedNameWhenDestinationExists() throws {
        let file = source.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)
        try Data("existing".utf8).write(to: destination.appendingPathComponent("note.txt"))

        let result = try CutPasteAction().paste(CutState(itemURLs: [file]), into: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("note 2.txt").path))
        XCTAssertEqual(result.movedURLs, [destination.appendingPathComponent("note 2.txt")])
    }

    func testMissingSourceThrowsAndDoesNotMoveOtherItems() throws {
        let missing = source.appendingPathComponent("missing.txt")
        let existing = source.appendingPathComponent("existing.txt")
        try Data().write(to: existing)

        XCTAssertThrowsError(try CutPasteAction().paste(CutState(itemURLs: [missing, existing]), into: destination)) { error in
            XCTAssertEqual(error as? ActionError, .sourceItemUnavailable(missing.path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: existing.path))
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter CutPasteActionTests
```

Expected: fails because `CutPasteAction`, `CutPasteResult`, and `sourceItemUnavailable` do not exist.

- [ ] **Step 3: Extend action errors**

Modify `Sources/RightClickCore/Actions/ActionModels.swift` so `ActionError` includes:

```swift
case noSelectedItems
case sourceItemUnavailable(String)
case pasteTargetUnavailable(String)
```

Add matching `errorDescription` cases:

```swift
case .noSelectedItems:
    return "No Finder items were selected."
case .sourceItemUnavailable(let path):
    return "The source item is unavailable: \(path)"
case .pasteTargetUnavailable(let path):
    return "The paste target is unavailable: \(path)"
```

- [ ] **Step 4: Add paste action**

Create `Sources/RightClickCore/CutPaste/CutPasteAction.swift`:

```swift
import Foundation

public struct CutPasteResult: Equatable {
    public let movedURLs: [URL]

    public init(movedURLs: [URL]) {
        self.movedURLs = movedURLs
    }
}

public struct CutPasteAction {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func paste(_ state: CutState, into targetDirectory: URL) throws -> CutPasteResult {
        guard directoryExists(targetDirectory) else {
            throw ActionError.pasteTargetUnavailable(targetDirectory.path)
        }

        for sourceURL in state.itemURLs {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw ActionError.sourceItemUnavailable(sourceURL.path)
            }
        }

        var movedURLs: [URL] = []
        for sourceURL in state.itemURLs {
            let destinationURL = try availableDestination(for: sourceURL, in: targetDirectory)
            do {
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
                movedURLs.append(destinationURL)
            } catch {
                throw ActionError.writeFailed(error.localizedDescription)
            }
        }

        return CutPasteResult(movedURLs: movedURLs)
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func availableDestination(for sourceURL: URL, in targetDirectory: URL) throws -> URL {
        let lastPathComponent = sourceURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lastPathComponent.isEmpty, lastPathComponent == (lastPathComponent as NSString).lastPathComponent else {
            throw ActionError.invalidFileName
        }

        let pathExtension = sourceURL.pathExtension
        let baseName = pathExtension.isEmpty
            ? lastPathComponent
            : sourceURL.deletingPathExtension().lastPathComponent

        for index in 1...500 {
            let suffix = index == 1 ? "" : " \(index)"
            let candidateName = pathExtension.isEmpty
                ? "\(baseName)\(suffix)"
                : "\(baseName)\(suffix).\(pathExtension)"
            let candidate = targetDirectory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw ActionError.collisionResolutionFailed
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter CutPasteActionTests
```

Expected: all cut/paste action tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/RightClickCore/Actions/ActionModels.swift Sources/RightClickCore/CutPaste/CutPasteAction.swift Tests/RightClickCoreTests/CutPasteActionTests.swift
git commit -m "feat: move cut Finder items"
```

## Task 5: Finder Extension Menu And Routes

**Files:**
- Modify: `RightClickFinderExtension/FinderSync.swift`

- [ ] **Step 1: Update watched locations and menu routing**

Replace `RightClickFinderExtension/FinderSync.swift` with:

```swift
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
            let item = NSMenuItem(title: "New File...", action: #selector(openNewFileWindow(_:)), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        if settings.isCutPasteEnabled {
            if !selectedURLs.isEmpty {
                let item = NSMenuItem(title: "Cut", action: #selector(cutSelectedItems(_:)), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }

            if hasCutState {
                let item = NSMenuItem(title: "Paste", action: #selector(pasteCutItems(_:)), keyEquivalent: "")
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
```

- [ ] **Step 2: Build app**

Run:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Xcode build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add RightClickFinderExtension/FinderSync.swift
git commit -m "feat: show configurable Finder actions"
```

## Task 6: Main App Routes For Cut And Paste

**Files:**
- Modify: `RightClick/AppDelegate.swift`
- Create: `RightClick/Error/ErrorView.swift`
- Modify: `RightClick.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add compact error view**

Create `RightClick/Error/ErrorView.swift`:

```swift
import SwiftUI

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RightClick")
                .font(.headline)
            Text(message)
                .font(.body)
                .frame(width: 360, alignment: .leading)
            HStack {
                Spacer()
                Button("OK") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
    }
}
```

- [ ] **Step 2: Update app delegate routing**

Replace `RightClick/AppDelegate.swift` with:

```swift
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
            let state = CutState(itemURLs: request.context.selectedItems.map(\.url))
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
```

- [ ] **Step 3: Build app**

Add `RightClick/Error/ErrorView.swift` to the `RightClick` target in `RightClick.xcodeproj/project.pbxproj`, following the existing `NewFileView.swift in Sources` pattern.

- [ ] **Step 4: Build app**

Run:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Xcode build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add RightClick/AppDelegate.swift RightClick/Error/ErrorView.swift RightClick.xcodeproj/project.pbxproj
git commit -m "feat: route Finder cut and paste actions"
```

## Task 7: Settings UI

**Files:**
- Create: `RightClick/Settings/SettingsView.swift`
- Modify: `RightClick/RightClickApp.swift`
- Modify: `RightClick.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add settings view**

Create `RightClick/Settings/SettingsView.swift`:

```swift
import SwiftUI
import RightClickCore

struct SettingsView: View {
    @State private var settings: AppSettings = .default
    @State private var message: String?
    private let store = SettingsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("New File", isOn: binding(\.isNewFileEnabled))
            Toggle("Cut / Paste", isOn: binding(\.isCutPasteEnabled))

            Divider()

            Button("Restart Finder") {
                restartFinder()
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 360, alignment: .leading)
        .onAppear {
            settings = ((try? store.load()) ?? .default)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                saveSettings()
            }
        )
    }

    private func saveSettings() {
        do {
            try store.save(settings)
            message = "Settings saved. They usually apply on the next right-click."
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]

        do {
            try process.run()
            message = "Finder restarted."
        } catch {
            message = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Add settings scene**

Replace `RightClick/RightClickApp.swift` with:

```swift
import SwiftUI

@main
struct RightClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("New File") {
            NewFileView(
                viewModel: NewFileViewModel(targetDirectory: appDelegate.latestTargetDirectory())
            )
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
```

- [ ] **Step 3: Add settings view to Xcode target**

Add `RightClick/Settings/SettingsView.swift` to the `RightClick` target in `RightClick.xcodeproj/project.pbxproj`, following the existing `NewFileView.swift in Sources` pattern.

- [ ] **Step 4: Build app**

Run:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Xcode build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add RightClick/Settings/SettingsView.swift RightClick/RightClickApp.swift RightClick.xcodeproj/project.pbxproj
git commit -m "feat: add action settings"
```

## Task 8: README Updates And Final Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README**

Edit `README.md` to add:

```markdown
## Settings

Open RightClick and choose RightClick > Settings.

Available modules:

- New File: shows `New File...` in Finder.
- Cut / Paste: shows `Cut` and `Paste` in Finder and moves files or folders. This module is disabled by default.

Settings are stored locally under `~/Library/Application Support/RightClick`. Finder usually reads changes on the next right-click. If Finder keeps showing old menu items, click `Restart Finder` in settings.

## Cut And Paste

Enable `Cut / Paste` in settings.

1. Select one or more files or folders in Finder.
2. Right-click and choose `Cut`.
3. Right-click the destination folder or a blank area inside the destination folder.
4. Choose `Paste`.

RightClick moves the cut items into the target directory. Existing target names are not overwritten; RightClick appends a number when needed.

## Finder Location Coverage

RightClick watches common Finder locations including the local disk, home folder, Desktop, iCloud Drive paths, and mounted volumes under `/Volumes`.

macOS Finder Sync extensions may still behave differently for some cloud providers, network drives, shared folders, or protected system locations. If a menu item does not appear after changing settings, use `Restart Finder` from settings or run:

```bash
killall Finder
```
```

- [ ] **Step 2: Run unit tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 3: Run Xcode build**

Run:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Xcode build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Install local app for manual verification**

Run:

```bash
ditto .build/Xcode/Build/Products/Debug/RightClick.app /Applications/RightClick.app
pluginkit -e use -i local.rightclick.RightClick.FinderExtension
killall Finder
```

Expected: RightClick is installed and Finder restarts.

- [ ] **Step 5: Manual checks**

Check:

```text
[ ] Desktop right-click shows enabled RightClick actions.
[ ] iCloud Drive right-click shows enabled RightClick actions where Finder Sync allows.
[ ] Network or shared volume right-click shows enabled RightClick actions where Finder Sync allows.
[ ] Disabling New File hides New File...
[ ] Enabling Cut / Paste shows Cut for selected files or folders.
[ ] Cut followed by Paste moves items to the expected folder.
[ ] Existing destination names are preserved with numbered names.
[ ] Restart Finder refreshes menu state.
```

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: document settings and cut paste"
```

## Final Verification

Run:

```bash
swift test
xcodebuild -project RightClick.xcodeproj -scheme RightClick -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Xcode build
git status --short
```

Expected:

- `swift test` passes.
- `xcodebuild` reports `BUILD SUCCEEDED`.
- `git status --short` is empty.

## Push

After all tasks are complete and verified:

```bash
git push
```

Expected: local commits are uploaded to `https://github.com/DX39062/rightclick.git`.
