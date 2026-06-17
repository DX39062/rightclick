# RightClick Finder New File Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a source-distributed macOS app that adds a Finder `New File...` context menu item and creates blank `txt`, `docx`, `xlsx`, `pptx`, `py`, and `md` files through a compact native window.

**Architecture:** Put testable domain logic in a Swift Package named `RightClickCore`, then consume it from a native macOS app and Finder Sync Extension. Keep the Finder extension thin: it captures Finder context, writes a request into an App Group container, and opens the main app. The main app owns UI, file generation, error handling, and future action modules.

**Tech Stack:** Swift 5.9+, Swift Package Manager for `RightClickCore`, XCTest, SwiftUI/AppKit for the main app, FinderSync framework for the extension, App Group shared container, ZIPFoundation for OpenXML package writing.

---

## File Structure

- `Package.swift`: Swift Package manifest for the testable core and ZIPFoundation dependency.
- `Sources/RightClickCore/Actions/ActionModels.swift`: shared action protocols and request/result models.
- `Sources/RightClickCore/Finder/FinderContext.swift`: selected-item and target-directory context models.
- `Sources/RightClickCore/Finder/TargetDirectoryResolver.swift`: Finder target location rules.
- `Sources/RightClickCore/NewFile/FileFormat.swift`: built-in file formats and extensions.
- `Sources/RightClickCore/NewFile/NameCollisionResolver.swift`: non-overwriting numbered filename logic.
- `Sources/RightClickCore/NewFile/NewFileAction.swift`: user input validation and execution orchestration.
- `Sources/RightClickCore/NewFile/TextFileWriter.swift`: empty UTF-8 file creation for `txt`, `md`, and `py`.
- `Sources/RightClickCore/NewFile/Office/OpenXMLPackageWriter.swift`: shared ZIP writing helper.
- `Sources/RightClickCore/NewFile/Office/DocxBuilder.swift`: minimal blank `.docx` package.
- `Sources/RightClickCore/NewFile/Office/XlsxBuilder.swift`: minimal blank `.xlsx` package.
- `Sources/RightClickCore/NewFile/Office/PptxBuilder.swift`: minimal blank `.pptx` package.
- `Sources/RightClickCore/Requests/ActionRequestStore.swift`: App Group request read/write abstraction.
- `Tests/RightClickCoreTests/*Tests.swift`: XCTest coverage for the core.
- `RightClick/RightClickApp.swift`: SwiftUI app entry point.
- `RightClick/AppDelegate.swift`: window activation and URL/event handling bridge.
- `RightClick/NewFile/NewFileView.swift`: compact new-file UI.
- `RightClick/NewFile/NewFileViewModel.swift`: UI state and command handling.
- `RightClick/Info.plist`: main app metadata and custom URL scheme.
- `RightClickFinderExtension/FinderSync.swift`: Finder menu item and context capture.
- `RightClickFinderExtension/Info.plist`: Finder Sync extension metadata.
- `RightClick.xcodeproj`: Xcode project containing the app target, extension target, and package dependency.
- `README.md`: local build, signing, and Finder extension enablement instructions.

## Task 1: Create Swift Package Core Skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/RightClickCore/Actions/ActionModels.swift`
- Create: `Sources/RightClickCore/Finder/FinderContext.swift`
- Create: `Tests/RightClickCoreTests/SmokeTests.swift`

- [ ] **Step 1: Create the package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RightClick",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "RightClickCore", targets: ["RightClickCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "RightClickCore",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .testTarget(
            name: "RightClickCoreTests",
            dependencies: ["RightClickCore"]
        )
    ]
)
```

- [ ] **Step 2: Add shared action models**

Create `Sources/RightClickCore/Actions/ActionModels.swift`:

```swift
import Foundation

public enum ActionError: Error, Equatable, LocalizedError {
    case missingTargetDirectory
    case targetDirectoryUnavailable(String)
    case unsupportedFormat(String)
    case invalidFileName
    case collisionResolutionFailed
    case writeFailed(String)
    case malformedRequest

    public var errorDescription: String? {
        switch self {
        case .missingTargetDirectory:
            return "No target directory was provided."
        case .targetDirectoryUnavailable(let path):
            return "The target directory is unavailable: \(path)"
        case .unsupportedFormat(let value):
            return "Unsupported file format: \(value)"
        case .invalidFileName:
            return "The file name is invalid."
        case .collisionResolutionFailed:
            return "Could not find an available file name."
        case .writeFailed(let message):
            return "File creation failed: \(message)"
        case .malformedRequest:
            return "The Finder action request is malformed."
        }
    }
}

public struct ActionResult: Equatable {
    public let createdURL: URL

    public init(createdURL: URL) {
        self.createdURL = createdURL
    }
}

public protocol ActionExecutor {
    associatedtype Input
    func execute(_ input: Input) throws -> ActionResult
}
```

- [ ] **Step 3: Add Finder context models**

Create `Sources/RightClickCore/Finder/FinderContext.swift`:

```swift
import Foundation

public struct FinderItem: Equatable, Codable {
    public let url: URL
    public let isDirectory: Bool

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }
}

public struct FinderContext: Equatable, Codable {
    public let currentDirectory: URL?
    public let selectedItems: [FinderItem]

    public init(currentDirectory: URL?, selectedItems: [FinderItem]) {
        self.currentDirectory = currentDirectory
        self.selectedItems = selectedItems
    }
}
```

- [ ] **Step 4: Add a smoke test**

Create `Tests/RightClickCoreTests/SmokeTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class SmokeTests: XCTestCase {
    func testFinderContextStoresCurrentDirectory() {
        let url = URL(fileURLWithPath: "/tmp/example", isDirectory: true)
        let context = FinderContext(currentDirectory: url, selectedItems: [])

        XCTAssertEqual(context.currentDirectory, url)
        XCTAssertTrue(context.selectedItems.isEmpty)
    }
}
```

- [ ] **Step 5: Run the smoke test**

Run:

```bash
swift test
```

Expected: package resolves ZIPFoundation and the smoke test passes.

- [ ] **Step 6: Commit**

Run:

```bash
git add Package.swift Sources Tests
git commit -m "feat: add core package skeleton"
```

## Task 2: Implement Finder Target Directory Resolution

**Files:**
- Create: `Sources/RightClickCore/Finder/TargetDirectoryResolver.swift`
- Create: `Tests/RightClickCoreTests/TargetDirectoryResolverTests.swift`

- [ ] **Step 1: Write failing target-resolution tests**

Create `Tests/RightClickCoreTests/TargetDirectoryResolverTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class TargetDirectoryResolverTests: XCTestCase {
    func testBlankAreaUsesCurrentDirectory() throws {
        let current = URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)
        let context = FinderContext(currentDirectory: current, selectedItems: [])

        XCTAssertEqual(try TargetDirectoryResolver.resolve(context), current)
    }

    func testSingleSelectedFolderCreatesInsideFolder() throws {
        let folder = URL(fileURLWithPath: "/Users/me/Desktop/Folder", isDirectory: true)
        let context = FinderContext(
            currentDirectory: URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true),
            selectedItems: [FinderItem(url: folder, isDirectory: true)]
        )

        XCTAssertEqual(try TargetDirectoryResolver.resolve(context), folder)
    }

    func testSingleSelectedFileCreatesBesideFile() throws {
        let file = URL(fileURLWithPath: "/Users/me/Desktop/report.pdf", isDirectory: false)
        let context = FinderContext(currentDirectory: nil, selectedItems: [FinderItem(url: file, isDirectory: false)])

        XCTAssertEqual(
            try TargetDirectoryResolver.resolve(context),
            URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)
        )
    }

    func testMultipleItemsCreateBesideFirstItemUnlessSingleFolder() throws {
        let file = URL(fileURLWithPath: "/Users/me/Desktop/a.txt", isDirectory: false)
        let folder = URL(fileURLWithPath: "/Users/me/Desktop/Folder", isDirectory: true)
        let context = FinderContext(
            currentDirectory: nil,
            selectedItems: [
                FinderItem(url: file, isDirectory: false),
                FinderItem(url: folder, isDirectory: true)
            ]
        )

        XCTAssertEqual(
            try TargetDirectoryResolver.resolve(context),
            URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)
        )
    }

    func testMissingContextThrows() {
        let context = FinderContext(currentDirectory: nil, selectedItems: [])

        XCTAssertThrowsError(try TargetDirectoryResolver.resolve(context)) { error in
            XCTAssertEqual(error as? ActionError, .missingTargetDirectory)
        }
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter TargetDirectoryResolverTests
```

Expected: FAIL because `TargetDirectoryResolver` does not exist.

- [ ] **Step 3: Implement resolver**

Create `Sources/RightClickCore/Finder/TargetDirectoryResolver.swift`:

```swift
import Foundation

public enum TargetDirectoryResolver {
    public static func resolve(_ context: FinderContext) throws -> URL {
        if context.selectedItems.isEmpty {
            guard let currentDirectory = context.currentDirectory else {
                throw ActionError.missingTargetDirectory
            }
            return currentDirectory
        }

        if context.selectedItems.count == 1 {
            let item = context.selectedItems[0]
            return item.isDirectory ? item.url : item.url.deletingLastPathComponent()
        }

        let first = context.selectedItems[0]
        return first.url.deletingLastPathComponent()
    }
}
```

- [ ] **Step 4: Run resolver tests**

Run:

```bash
swift test --filter TargetDirectoryResolverTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/RightClickCore/Finder Tests/RightClickCoreTests/TargetDirectoryResolverTests.swift
git commit -m "feat: resolve Finder target directories"
```

## Task 3: Implement File Formats and Collision-Free Names

**Files:**
- Create: `Sources/RightClickCore/NewFile/FileFormat.swift`
- Create: `Sources/RightClickCore/NewFile/NameCollisionResolver.swift`
- Create: `Tests/RightClickCoreTests/FileFormatTests.swift`
- Create: `Tests/RightClickCoreTests/NameCollisionResolverTests.swift`

- [ ] **Step 1: Write failing format tests**

Create `Tests/RightClickCoreTests/FileFormatTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class FileFormatTests: XCTestCase {
    func testBuiltInFormatsAreInDisplayOrder() {
        XCTAssertEqual(FileFormat.builtIn.map(\.rawValue), ["txt", "docx", "xlsx", "pptx", "py", "md"])
    }

    func testExtensionValues() throws {
        XCTAssertEqual(try FileFormat.parse("txt").fileExtension, "txt")
        XCTAssertEqual(try FileFormat.parse("DOCX").fileExtension, "docx")
        XCTAssertEqual(try FileFormat.parse("md").fileExtension, "md")
    }

    func testUnsupportedFormatThrows() {
        XCTAssertThrowsError(try FileFormat.parse("pdf")) { error in
            XCTAssertEqual(error as? ActionError, .unsupportedFormat("pdf"))
        }
    }
}
```

- [ ] **Step 2: Write failing collision tests**

Create `Tests/RightClickCoreTests/NameCollisionResolverTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class NameCollisionResolverTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testUsesBaseNameWhenAvailable() throws {
        let url = try NameCollisionResolver.availableURL(
            directory: directory,
            baseName: "Untitled",
            fileExtension: "txt"
        )

        XCTAssertEqual(url.lastPathComponent, "Untitled.txt")
    }

    func testAppendsNumberWhenNameExists() throws {
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("Untitled.txt").path,
            contents: Data()
        )

        let url = try NameCollisionResolver.availableURL(
            directory: directory,
            baseName: "Untitled",
            fileExtension: "txt"
        )

        XCTAssertEqual(url.lastPathComponent, "Untitled 2.txt")
    }

    func testTrimsWhitespaceAndRejectsEmptyName() {
        XCTAssertThrowsError(
            try NameCollisionResolver.availableURL(directory: directory, baseName: "   ", fileExtension: "txt")
        ) { error in
            XCTAssertEqual(error as? ActionError, .invalidFileName)
        }
    }
}
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
swift test --filter FileFormatTests
swift test --filter NameCollisionResolverTests
```

Expected: FAIL because `FileFormat` and `NameCollisionResolver` do not exist.

- [ ] **Step 4: Implement file formats**

Create `Sources/RightClickCore/NewFile/FileFormat.swift`:

```swift
import Foundation

public enum FileFormat: String, CaseIterable, Codable, Equatable, Identifiable {
    case txt
    case docx
    case xlsx
    case pptx
    case py
    case md

    public var id: String { rawValue }

    public static let builtIn: [FileFormat] = [.txt, .docx, .xlsx, .pptx, .py, .md]

    public var fileExtension: String { rawValue }

    public static func parse(_ value: String) throws -> FileFormat {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let format = FileFormat(rawValue: normalized) else {
            throw ActionError.unsupportedFormat(value)
        }
        return format
    }
}
```

- [ ] **Step 5: Implement collision resolver**

Create `Sources/RightClickCore/NewFile/NameCollisionResolver.swift`:

```swift
import Foundation

public enum NameCollisionResolver {
    public static func availableURL(
        directory: URL,
        baseName: String,
        fileExtension: String,
        fileManager: FileManager = .default,
        retryLimit: Int = 500
    ) throws -> URL {
        let cleanBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBaseName.isEmpty else {
            throw ActionError.invalidFileName
        }

        for index in 1...retryLimit {
            let suffix = index == 1 ? "" : " \(index)"
            let candidate = directory.appendingPathComponent("\(cleanBaseName)\(suffix).\(fileExtension)")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw ActionError.collisionResolutionFailed
    }
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter FileFormatTests
swift test --filter NameCollisionResolverTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/RightClickCore/NewFile Tests/RightClickCoreTests/FileFormatTests.swift Tests/RightClickCoreTests/NameCollisionResolverTests.swift
git commit -m "feat: add new file formats and collision handling"
```

## Task 4: Implement Text File Creation and New File Action

**Files:**
- Create: `Sources/RightClickCore/NewFile/TextFileWriter.swift`
- Create: `Sources/RightClickCore/NewFile/NewFileAction.swift`
- Create: `Tests/RightClickCoreTests/NewFileActionTests.swift`

- [ ] **Step 1: Write failing action tests**

Create `Tests/RightClickCoreTests/NewFileActionTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class NewFileActionTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCreatesEmptyTxtFile() throws {
        let action = NewFileAction()

        let result = try action.execute(
            NewFileInput(directory: directory, baseName: "Notes", format: .txt)
        )

        XCTAssertEqual(result.createdURL.lastPathComponent, "Notes.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.createdURL.path))
        XCTAssertEqual(try Data(contentsOf: result.createdURL), Data())
    }

    func testCreatesMarkdownWithCollisionSuffix() throws {
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("Untitled.md").path,
            contents: Data()
        )
        let action = NewFileAction()

        let result = try action.execute(
            NewFileInput(directory: directory, baseName: "Untitled", format: .md)
        )

        XCTAssertEqual(result.createdURL.lastPathComponent, "Untitled 2.md")
    }

    func testRejectsMissingDirectory() {
        let missing = directory.appendingPathComponent("Missing", isDirectory: true)
        let action = NewFileAction()

        XCTAssertThrowsError(
            try action.execute(NewFileInput(directory: missing, baseName: "File", format: .py))
        ) { error in
            XCTAssertEqual(error as? ActionError, .targetDirectoryUnavailable(missing.path))
        }
    }
}
```

- [ ] **Step 2: Run action tests and verify failure**

Run:

```bash
swift test --filter NewFileActionTests
```

Expected: FAIL because `NewFileAction` and `NewFileInput` do not exist.

- [ ] **Step 3: Implement text file writer**

Create `Sources/RightClickCore/NewFile/TextFileWriter.swift`:

```swift
import Foundation

public enum TextFileWriter {
    public static func writeEmptyFile(to url: URL) throws {
        do {
            try Data().write(to: url, options: .withoutOverwriting)
        } catch {
            throw ActionError.writeFailed(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 4: Implement new file action for text formats**

Create `Sources/RightClickCore/NewFile/NewFileAction.swift`:

```swift
import Foundation

public struct NewFileInput: Equatable {
    public let directory: URL
    public let baseName: String
    public let format: FileFormat

    public init(directory: URL, baseName: String, format: FileFormat) {
        self.directory = directory
        self.baseName = baseName
        self.format = format
    }
}

public struct NewFileAction: ActionExecutor {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func execute(_ input: NewFileInput) throws -> ActionResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: input.directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ActionError.targetDirectoryUnavailable(input.directory.path)
        }

        let destination = try NameCollisionResolver.availableURL(
            directory: input.directory,
            baseName: input.baseName,
            fileExtension: input.format.fileExtension,
            fileManager: fileManager
        )

        switch input.format {
        case .txt, .md, .py:
            try TextFileWriter.writeEmptyFile(to: destination)
        case .docx:
            try DocxBuilder.writeBlankDocument(to: destination)
        case .xlsx:
            try XlsxBuilder.writeBlankWorkbook(to: destination)
        case .pptx:
            try PptxBuilder.writeBlankPresentation(to: destination)
        }

        return ActionResult(createdURL: destination)
    }
}
```

- [ ] **Step 5: Add temporary Office stubs so text tests compile**

Create `Sources/RightClickCore/NewFile/Office/DocxBuilder.swift`:

```swift
import Foundation

public enum DocxBuilder {
    public static func writeBlankDocument(to url: URL) throws {
        throw ActionError.unsupportedFormat("docx")
    }
}
```

Create `Sources/RightClickCore/NewFile/Office/XlsxBuilder.swift`:

```swift
import Foundation

public enum XlsxBuilder {
    public static func writeBlankWorkbook(to url: URL) throws {
        throw ActionError.unsupportedFormat("xlsx")
    }
}
```

Create `Sources/RightClickCore/NewFile/Office/PptxBuilder.swift`:

```swift
import Foundation

public enum PptxBuilder {
    public static func writeBlankPresentation(to url: URL) throws {
        throw ActionError.unsupportedFormat("pptx")
    }
}
```

- [ ] **Step 6: Run action tests**

Run:

```bash
swift test --filter NewFileActionTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/RightClickCore/NewFile Tests/RightClickCoreTests/NewFileActionTests.swift
git commit -m "feat: create text new files"
```

## Task 5: Implement Valid Blank Office Packages

**Files:**
- Create: `Sources/RightClickCore/NewFile/Office/OpenXMLPackageWriter.swift`
- Modify: `Sources/RightClickCore/NewFile/Office/DocxBuilder.swift`
- Modify: `Sources/RightClickCore/NewFile/Office/XlsxBuilder.swift`
- Modify: `Sources/RightClickCore/NewFile/Office/PptxBuilder.swift`
- Create: `Tests/RightClickCoreTests/OfficeBuilderTests.swift`

- [ ] **Step 1: Write failing Office tests**

Create `Tests/RightClickCoreTests/OfficeBuilderTests.swift`:

```swift
import XCTest
import ZIPFoundation
@testable import RightClickCore

final class OfficeBuilderTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testDocxContainsRequiredEntries() throws {
        let url = directory.appendingPathComponent("Blank.docx")
        try DocxBuilder.writeBlankDocument(to: url)

        let names = try archiveEntryNames(url)
        XCTAssertTrue(names.contains("[Content_Types].xml"))
        XCTAssertTrue(names.contains("_rels/.rels"))
        XCTAssertTrue(names.contains("word/document.xml"))
        XCTAssertTrue(names.contains("word/_rels/document.xml.rels"))
    }

    func testXlsxContainsRequiredEntries() throws {
        let url = directory.appendingPathComponent("Blank.xlsx")
        try XlsxBuilder.writeBlankWorkbook(to: url)

        let names = try archiveEntryNames(url)
        XCTAssertTrue(names.contains("[Content_Types].xml"))
        XCTAssertTrue(names.contains("_rels/.rels"))
        XCTAssertTrue(names.contains("xl/workbook.xml"))
        XCTAssertTrue(names.contains("xl/worksheets/sheet1.xml"))
    }

    func testPptxContainsRequiredEntries() throws {
        let url = directory.appendingPathComponent("Blank.pptx")
        try PptxBuilder.writeBlankPresentation(to: url)

        let names = try archiveEntryNames(url)
        XCTAssertTrue(names.contains("[Content_Types].xml"))
        XCTAssertTrue(names.contains("_rels/.rels"))
        XCTAssertTrue(names.contains("ppt/presentation.xml"))
        XCTAssertTrue(names.contains("ppt/slides/slide1.xml"))
    }

    private func archiveEntryNames(_ url: URL) throws -> Set<String> {
        guard let archive = Archive(url: url, accessMode: .read) else {
            XCTFail("Expected readable ZIP archive at \(url.path)")
            return []
        }
        return Set(archive.map(\.path))
    }
}
```

- [ ] **Step 2: Run Office tests and verify failure**

Run:

```bash
swift test --filter OfficeBuilderTests
```

Expected: FAIL because the builders still throw unsupported-format errors.

- [ ] **Step 3: Implement OpenXML package writer**

Create `Sources/RightClickCore/NewFile/Office/OpenXMLPackageWriter.swift`:

```swift
import Foundation
import ZIPFoundation

enum OpenXMLPackageWriter {
    static func write(entries: [String: String], to url: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            throw ActionError.writeFailed("Destination already exists: \(url.path)")
        }

        guard let archive = Archive(url: url, accessMode: .create) else {
            throw ActionError.writeFailed("Could not create archive at \(url.path)")
        }

        do {
            for path in entries.keys.sorted() {
                let data = Data(entries[path]!.utf8)
                try archive.addEntry(with: path, type: .file, uncompressedSize: UInt32(data.count)) { position, size in
                    data.subdata(in: Int(position)..<Int(position + size))
                }
            }
        } catch {
            try? fileManager.removeItem(at: url)
            throw ActionError.writeFailed(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 4: Replace Docx builder**

Replace `Sources/RightClickCore/NewFile/Office/DocxBuilder.swift` with:

```swift
import Foundation

public enum DocxBuilder {
    public static func writeBlankDocument(to url: URL) throws {
        try OpenXMLPackageWriter.write(entries: [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            </Types>
            """,
            "_rels/.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
            </Relationships>
            """,
            "word/_rels/document.xml.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
            """,
            "word/document.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body>
                <w:p/>
                <w:sectPr>
                  <w:pgSz w:w="12240" w:h="15840"/>
                  <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
                </w:sectPr>
              </w:body>
            </w:document>
            """
        ], to: url)
    }
}
```

- [ ] **Step 5: Replace Xlsx builder**

Replace `Sources/RightClickCore/NewFile/Office/XlsxBuilder.swift` with:

```swift
import Foundation

public enum XlsxBuilder {
    public static func writeBlankWorkbook(to url: URL) throws {
        try OpenXMLPackageWriter.write(entries: [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
              <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            </Types>
            """,
            "_rels/.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            </Relationships>
            """,
            "xl/_rels/workbook.xml.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
            </Relationships>
            """,
            "xl/workbook.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <sheets>
                <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
              </sheets>
            </workbook>
            """,
            "xl/worksheets/sheet1.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData/>
            </worksheet>
            """
        ], to: url)
    }
}
```

- [ ] **Step 6: Replace Pptx builder**

Replace `Sources/RightClickCore/NewFile/Office/PptxBuilder.swift` with:

```swift
import Foundation

public enum PptxBuilder {
    public static func writeBlankPresentation(to url: URL) throws {
        try OpenXMLPackageWriter.write(entries: [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
              <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
            </Types>
            """,
            "_rels/.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
            </Relationships>
            """,
            "ppt/_rels/presentation.xml.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
            </Relationships>
            """,
            "ppt/presentation.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <p:sldIdLst>
                <p:sldId id="256" r:id="rId1"/>
              </p:sldIdLst>
              <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>
            </p:presentation>
            """,
            "ppt/slides/slide1.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <p:cSld>
                <p:spTree>
                  <p:nvGrpSpPr>
                    <p:cNvPr id="1" name=""/>
                    <p:cNvGrpSpPr/>
                    <p:nvPr/>
                  </p:nvGrpSpPr>
                  <p:grpSpPr>
                    <a:xfrm>
                      <a:off x="0" y="0"/>
                      <a:ext cx="0" cy="0"/>
                      <a:chOff x="0" y="0"/>
                      <a:chExt cx="0" cy="0"/>
                    </a:xfrm>
                  </p:grpSpPr>
                </p:spTree>
              </p:cSld>
            </p:sld>
            """
        ], to: url)
    }
}
```

- [ ] **Step 7: Run Office and action tests**

Run:

```bash
swift test --filter OfficeBuilderTests
swift test --filter NewFileActionTests
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/RightClickCore/NewFile/Office Tests/RightClickCoreTests/OfficeBuilderTests.swift
git commit -m "feat: generate blank Office files"
```

## Task 6: Implement App Group Request Store

**Files:**
- Create: `Sources/RightClickCore/Requests/ActionRequestStore.swift`
- Create: `Tests/RightClickCoreTests/ActionRequestStoreTests.swift`

- [ ] **Step 1: Write failing request-store tests**

Create `Tests/RightClickCoreTests/ActionRequestStoreTests.swift`:

```swift
import XCTest
@testable import RightClickCore

final class ActionRequestStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testWritesAndReadsLatestRequest() throws {
        let store = ActionRequestStore(containerDirectory: directory)
        let request = FinderActionRequest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 10),
            context: FinderContext(
                currentDirectory: URL(fileURLWithPath: "/tmp", isDirectory: true),
                selectedItems: []
            )
        )

        try store.write(request)

        XCTAssertEqual(try store.readLatest(), request)
    }

    func testMissingRequestThrowsMalformedRequest() {
        let store = ActionRequestStore(containerDirectory: directory)

        XCTAssertThrowsError(try store.readLatest()) { error in
            XCTAssertEqual(error as? ActionError, .malformedRequest)
        }
    }
}
```

- [ ] **Step 2: Run request-store tests and verify failure**

Run:

```bash
swift test --filter ActionRequestStoreTests
```

Expected: FAIL because `ActionRequestStore` does not exist.

- [ ] **Step 3: Implement request store**

Create `Sources/RightClickCore/Requests/ActionRequestStore.swift`:

```swift
import Foundation

public struct FinderActionRequest: Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let context: FinderContext

    public init(id: UUID = UUID(), createdAt: Date = Date(), context: FinderContext) {
        self.id = id
        self.createdAt = createdAt
        self.context = context
    }
}

public struct ActionRequestStore {
    public static let defaultFileName = "latest-finder-action-request.json"

    private let containerDirectory: URL
    private let fileManager: FileManager

    public init(containerDirectory: URL, fileManager: FileManager = .default) {
        self.containerDirectory = containerDirectory
        self.fileManager = fileManager
    }

    public func write(_ request: FinderActionRequest) throws {
        try fileManager.createDirectory(at: containerDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.rightClick.encode(request)
        try data.write(to: requestURL, options: .atomic)
    }

    public func readLatest() throws -> FinderActionRequest {
        guard fileManager.fileExists(atPath: requestURL.path) else {
            throw ActionError.malformedRequest
        }
        do {
            let data = try Data(contentsOf: requestURL)
            return try JSONDecoder.rightClick.decode(FinderActionRequest.self, from: data)
        } catch {
            throw ActionError.malformedRequest
        }
    }

    private var requestURL: URL {
        containerDirectory.appendingPathComponent(Self.defaultFileName)
    }
}

private extension JSONEncoder {
    static var rightClick: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var rightClick: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
```

- [ ] **Step 4: Run request-store tests**

Run:

```bash
swift test --filter ActionRequestStoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/RightClickCore/Requests Tests/RightClickCoreTests/ActionRequestStoreTests.swift
git commit -m "feat: store Finder action requests"
```

## Task 7: Scaffold macOS App and Compact Window

**Files:**
- Create: `RightClick/RightClickApp.swift`
- Create: `RightClick/AppDelegate.swift`
- Create: `RightClick/NewFile/NewFileView.swift`
- Create: `RightClick/NewFile/NewFileViewModel.swift`
- Create: `RightClick/Info.plist`
- Create/Modify: `RightClick.xcodeproj`

- [ ] **Step 1: Create the Xcode project**

Use Xcode to create a macOS App project in the repository root:

```text
Product Name: RightClick
Interface: SwiftUI
Language: Swift
Minimum Deployment: macOS 13.0
```

Then add the local package dependency:

```text
File > Add Package Dependencies... > Add Local... > repository root > RightClickCore
```

Expected: `RightClick.xcodeproj` exists and the app target links `RightClickCore`.

- [ ] **Step 2: Add app entry**

Create `RightClick/RightClickApp.swift`:

```swift
import SwiftUI

@main
struct RightClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("New File") {
            NewFileView(viewModel: NewFileViewModel.preview())
        }
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 3: Add app delegate**

Create `RightClick/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 4: Add view model**

Create `RightClick/NewFile/NewFileViewModel.swift`:

```swift
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
```

- [ ] **Step 5: Add compact view**

Create `RightClick/NewFile/NewFileView.swift`:

```swift
import SwiftUI
import RightClickCore

struct NewFileView: View {
    @ObservedObject var viewModel: NewFileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New File")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("File name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Untitled", text: $viewModel.baseName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Format")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Format", selection: $viewModel.selectedFormat) {
                    ForEach(FileFormat.builtIn) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.targetDirectory.path)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 320, alignment: .leading)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 320, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    viewModel.create()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
    }
}
```

- [ ] **Step 6: Build app target**

Run:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

Run:

```bash
git add RightClick RightClick.xcodeproj
git commit -m "feat: add compact new file app"
```

## Task 8: Connect Main App to Stored Finder Requests

**Files:**
- Modify: `RightClick/AppDelegate.swift`
- Modify: `RightClick/RightClickApp.swift`
- Modify: `RightClick/NewFile/NewFileViewModel.swift`
- Create: `RightClick/Shared/AppGroup.swift`

- [ ] **Step 1: Add App Group helper**

Create `RightClick/Shared/AppGroup.swift`:

```swift
import Foundation

enum AppGroup {
    static let identifier = "group.local.rightclick"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("RightClick", isDirectory: true)
        }
        return url
    }
}
```

- [ ] **Step 2: Replace app delegate with request loading**

Replace `RightClick/AppDelegate.swift` with:

```swift
import AppKit
import RightClickCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func latestTargetDirectory() -> URL {
        let store = ActionRequestStore(containerDirectory: AppGroup.containerURL)
        do {
            let request = try store.readLatest()
            return try TargetDirectoryResolver.resolve(request.context)
        } catch {
            return FileManager.default.homeDirectoryForCurrentUser
        }
    }
}
```

- [ ] **Step 3: Update app entry to load target directory**

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
    }
}
```

- [ ] **Step 4: Build app target**

Run:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

Run:

```bash
git add RightClick
git commit -m "feat: load Finder request in app"
```

## Task 9: Add Finder Sync Extension

**Files:**
- Create: `RightClickFinderExtension/FinderSync.swift`
- Create: `RightClickFinderExtension/Info.plist`
- Modify: `RightClick.xcodeproj`

- [ ] **Step 1: Add Finder Sync Extension target in Xcode**

In Xcode:

```text
File > New > Target... > macOS > Finder Sync Extension
Product Name: RightClickFinderExtension
Language: Swift
Embed in Application: RightClick
```

Then link `RightClickCore` to the extension target.

Expected: `RightClickFinderExtension.appex` is embedded in `RightClick.app`.

- [ ] **Step 2: Replace FinderSync implementation**

Replace `RightClickFinderExtension/FinderSync.swift` with:

```swift
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
            let store = ActionRequestStore(containerDirectory: appGroupContainerURL())
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

    private func appGroupContainerURL() -> URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.local.rightclick")
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("RightClick", isDirectory: true)
    }

    private func openMainApp() {
        let bundleIdentifier = "local.rightclick.RightClick"
        NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleIdentifier, options: [.default], additionalEventParamDescriptor: nil, launchIdentifier: nil)
    }
}
```

- [ ] **Step 3: Configure bundle identifiers and App Group**

In Xcode Signing & Capabilities:

```text
RightClick bundle identifier: local.rightclick.RightClick
RightClickFinderExtension bundle identifier: local.rightclick.RightClick.FinderExtension
App Group on both targets: group.local.rightclick
Signing: automatic signing with local Personal Team or ad-hoc local signing
```

Expected: both targets have matching App Group entitlement.

- [ ] **Step 4: Build both targets**

Run:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED and the extension target is built.

- [ ] **Step 5: Commit**

Run:

```bash
git add RightClickFinderExtension RightClick.xcodeproj
git commit -m "feat: add Finder new file extension"
```

## Task 10: Add README and Manual Verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README**

Create `README.md`:

```markdown
# RightClick

RightClick is a personal macOS Finder extension for adding modular right-click actions. Version one adds `New File...` to Finder and creates blank files in these formats:

- `txt`
- `docx`
- `xlsx`
- `pptx`
- `py`
- `md`

## Requirements

- macOS 13 Ventura or newer
- Xcode
- No paid Apple Developer account required for local source builds

## Build

Open `RightClick.xcodeproj` in Xcode and build the `RightClick` scheme.

If Xcode asks for signing settings, use your local Personal Team or local development signing. The project is intended for source distribution, not notarized binary distribution.

## Enable Finder Extension

After building and running the app:

1. Open System Settings.
2. Go to Privacy & Security > Extensions > Finder Extensions.
3. Enable RightClick.
4. Relaunch Finder if the menu item does not appear immediately:

```bash
killall Finder
```

## Usage

In Finder, right-click a blank area, file, or folder and choose `New File...`.

The target location is resolved as follows:

- Blank area: current Finder folder
- Selected folder: inside that folder
- Selected file: beside that file
- Multiple selected items: beside the first selected item, unless exactly one folder is selected

If a file already exists, RightClick appends a number, such as `Untitled 2.txt`.

## Development

Run core tests:

```bash
swift test
```

Build the app:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -destination 'platform=macOS' build
```
```

- [ ] **Step 2: Run full automated verification**

Run:

```bash
swift test
xcodebuild -project RightClick.xcodeproj -scheme RightClick -destination 'platform=macOS' build
```

Expected: tests pass and Xcode build succeeds.

- [ ] **Step 3: Perform manual Finder verification**

Manual checklist:

```text
[ ] RightClick builds and launches.
[ ] RightClick Finder Extension can be enabled in System Settings.
[ ] Finder right-click menu still shows original Finder items.
[ ] Finder right-click menu includes New File...
[ ] Blank-area invocation creates in the current Finder folder.
[ ] Selected-folder invocation creates inside the selected folder.
[ ] Selected-file invocation creates beside the selected file.
[ ] txt, md, and py files are created as empty files.
[ ] docx, xlsx, and pptx files open as valid blank Office files.
[ ] Existing names produce numbered files instead of overwriting.
```

- [ ] **Step 4: Commit**

Run:

```bash
git add README.md
git commit -m "docs: add build and verification instructions"
```

## Final Verification

Run:

```bash
swift test
xcodebuild -project RightClick.xcodeproj -scheme RightClick -destination 'platform=macOS' build
git status --short
```

Expected:

- `swift test` passes.
- `xcodebuild` reports `BUILD SUCCEEDED`.
- `git status --short` is empty after the final commit.

