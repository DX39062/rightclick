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

Run core build verification:

```bash
swift build
```

Run core tests in an environment with XCTest available:

```bash
swift test
```

Build the app and Finder extension with Xcode:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -destination 'platform=macOS' build
```

## Manual Verification

- RightClick builds and launches.
- RightClick Finder Extension can be enabled in System Settings.
- Finder right-click menu still shows original Finder items.
- Finder right-click menu includes `New File...`.
- Blank-area invocation creates in the current Finder folder.
- Selected-folder invocation creates inside the selected folder.
- Selected-file invocation creates beside the selected file.
- `txt`, `md`, and `py` files are created as empty files.
- `docx`, `xlsx`, and `pptx` files open as valid blank Office files.
- Existing names produce numbered files instead of overwriting.
