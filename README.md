# RightClick

RightClick is a personal macOS Finder extension for adding modular right-click actions.

Modules:

- New File shows `New File...` in Finder and creates blank files in these formats:

  - `txt`
  - `docx`
  - `xlsx`
  - `pptx`
  - `py`
  - `md`
- Cut / Paste shows `Cut` and `Paste`, moves files and folders, and is disabled by default.

## Requirements

- macOS 13 Ventura or newer
- Xcode from the Mac App Store
- Git
- No paid Apple Developer account required for local source builds

## Build From Source

Clone the repository and enter the project directory:

```bash
git clone <repository-url>
cd rightclick
```

If this is the first time you have installed Xcode, open Xcode once and accept the license. You can also verify the command line tools:

```bash
xcodebuild -version
```

Build the app and Finder extension:

```bash
xcodebuild -project RightClick.xcodeproj -scheme RightClick -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Xcode build
```

Install the locally built app:

```bash
ditto .build/Xcode/Build/Products/Debug/RightClick.app /Applications/RightClick.app
```

The project uses Xcode's local signing for Debug builds, so a paid Apple Developer account is not required. The app is intended for local source builds, not notarized binary distribution.

## Enable Finder Extension

1. Open System Settings.
2. Go to General > Login Items & Extensions.
3. Open Finder Extensions.
4. Enable RightClick or RightClick Finder Extension.
5. Relaunch Finder if the menu item does not appear immediately:

```bash
killall Finder
```

You can verify that macOS registered the extension:

```bash
pluginkit -m -p com.apple.FinderSync | grep RightClick
```

A leading `+` means the extension is enabled.

## Usage

Open RightClick and choose RightClick > Settings to enable or disable modules. Settings are stored locally under `~/Library/Application Support/RightClick`.

Settings usually apply on the next Finder right-click. If an old menu remains visible, use Restart Finder in settings or run:

```bash
killall Finder
```

### New File

In Finder, right-click a blank area, file, or folder and choose `New File...`.

The target location is resolved as follows:

- Blank area: current Finder folder
- Selected folder: inside that folder
- Selected file: beside that file
- Multiple selected items: beside the first selected item, unless exactly one folder is selected

If a file already exists, RightClick appends a number, such as `Untitled 2.txt`.

### Cut / Paste

1. Enable Cut / Paste in settings.
2. Select one or more files/folders.
3. Right-click and choose Cut.
4. Right-click the destination folder or a blank area inside the destination folder.
5. Choose Paste.

RightClick avoids overwriting existing target names by appending numbers.

### Finder Locations

RightClick watches local disk locations, the home folder, Desktop, iCloud Drive paths, and mounted volumes under `/Volumes`. macOS Finder Sync behavior may still vary for cloud, network, shared, or protected locations.

## Updating

After pulling new source changes, rebuild and reinstall:

```bash
git pull
xcodebuild -project RightClick.xcodeproj -scheme RightClick -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Xcode build
ditto .build/Xcode/Build/Products/Debug/RightClick.app /Applications/RightClick.app
pluginkit -e use -i local.rightclick.RightClick.FinderExtension
killall Finder
```

## Troubleshooting

If `New File...`, `Cut`, or `Paste` does not appear in Finder:

1. Confirm `/Applications/RightClick.app` exists.
2. Confirm the Finder extension is enabled in System Settings.
3. Open RightClick and choose RightClick > Settings to confirm the module is enabled.
4. Re-enable the Finder extension from Terminal:

```bash
pluginkit -e use -i local.rightclick.RightClick.FinderExtension
killall Finder
```

If you built and ran from Xcode, install the app to `/Applications` again. Finder extensions are more reliable when registered from the installed app bundle instead of Xcode's temporary build directory.

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
