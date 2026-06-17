# RightClick Finder New File Design

Date: 2026-06-17

## Summary

RightClick is a native macOS utility for adding personal, modular actions to the Finder context menu. The first version focuses on one Finder action: `New File...`.

The action appears as an additional Finder menu item. It does not replace, hide, or reorder Finder's built-in context menu items. Selecting `New File...` opens a compact native window where the user chooses a file name and format, then creates a blank file in the resolved Finder location.

The project is source-distributed through a git repository. It does not require an Apple Developer account, App Store distribution, Developer ID notarization, or paid signing for the first version. Users build and run it locally with Xcode and enable the Finder extension in macOS settings.

Minimum supported macOS version: macOS 13 Ventura.

## Goals

- Add a native Finder context menu entry named `New File...`.
- Preserve the original Finder right-click menu.
- Open a compact native dialog for creating a blank file.
- Support these built-in formats: `txt`, `docx`, `xlsx`, `pptx`, `py`, `md`.
- Generate valid blank Office files for `docx`, `xlsx`, and `pptx`.
- Automatically avoid name collisions by appending a number.
- Keep the Finder extension thin and move reusable behavior into shared modules.
- Design the first action as a module so later Finder actions can reuse the same architecture.

## Non-Goals

- Supporting right-click menus inside arbitrary apps.
- Replacing Finder's built-in context menu.
- Shipping signed or notarized binary releases.
- App Store distribution.
- User-defined custom templates in the first version.
- A large command palette or category sidebar in the first version.
- Automator, Shortcuts, or Services-based implementation.

## Architecture

The app uses a native macOS structure:

- `RightClick.app`: Main app. Owns settings, the `New File...` window, file generation, user-facing errors, and future action management.
- `RightClickFinderExtension.appex`: Finder Sync Extension. Adds `New File...` to Finder's context menu and passes Finder context to the main app.
- `SharedCore`: Shared Swift module used by the app and extension. Contains action protocols, path resolution, file format definitions, file-name collision handling, and shared request models.
- App Group container: Shared storage used to pass short-lived action requests from the Finder extension to the main app.

The Finder extension stays intentionally small. It should not contain Office file generation, UI state, template logic, or future action execution logic. Its job is to determine the Finder context, write an action request to the App Group container, and open the main app.

## Finder Menu Behavior

The extension adds one menu item:

- `New File...`

Finder's original context menu remains intact. The custom item is appended by the Finder Sync Extension in the area macOS allows for extension-provided menu items. The app does not attempt to remove, replace, reorder, or fully control Finder's native menu.

## Target Location Rules

The app resolves the creation directory from Finder context:

- Right-click Finder blank area: create in the current Finder folder.
- Right-click a selected folder: create inside that folder.
- Right-click a selected file: create beside that file, in its parent folder.
- Multi-select: if exactly one folder is selected, create inside it; otherwise create beside the first selected item.

Path resolution should happen through one shared helper in `SharedCore` so action modules do not duplicate Finder-specific rules.

## New File Window

The first version uses a compact native window:

- File name input, default value `Untitled`.
- Format selector with `txt`, `docx`, `xlsx`, `pptx`, `py`, and `md`.
- Read-only target path display.
- `Cancel` and `Create` buttons.

When creation succeeds, the window closes. The app should attempt to reveal or select the new file in Finder. If Finder selection fails, file creation is still considered successful.

## Name Collision Handling

The app never overwrites an existing file in the first version.

If the requested name already exists, the file creator appends a number before the extension:

- `Untitled.txt`
- `Untitled 2.txt`
- `Untitled 3.txt`

This rule applies to all supported formats.

## File Generation

Text-like formats are created as empty files:

- `txt`: empty UTF-8 file.
- `md`: empty UTF-8 file.
- `py`: empty UTF-8 file.

Office formats must be valid OpenXML packages, not zero-byte files:

- `docx`: minimal valid blank Word document package.
- `xlsx`: minimal valid blank Excel workbook package.
- `pptx`: minimal valid blank PowerPoint presentation package.

The first version generates these packages directly in Swift, using small in-repo package builders. It does not require external command-line tools, Python packages, or user-provided template files.

## Modular Action Model

The first action is implemented through a reusable action model:

- `ActionModule`: describes a Finder action module, such as `NewFileAction`.
- `ActionRequest`: carries Finder context, resolved target directory, selected items, and trigger metadata.
- `ActionUI`: describes whether the action needs UI before execution.
- `ActionExecutor`: performs the action and returns success or a typed error.

`NewFileAction` is the only module in version one, but the boundaries should make later modules possible without rewriting the Finder extension.

## Error Handling

User-facing errors should be specific and recoverable:

- Target directory missing or unavailable.
- No write permission in target directory.
- Unsupported file format.
- Office package generation failed.
- File already exists after collision resolution retry limit is reached.
- Main app could not read the request written by the extension.

The app should not silently fail. The Finder extension should avoid presenting complex UI; detailed errors belong in the main app.

## Testing

Focused tests should cover:

- Target directory resolution for blank area, selected folder, selected file, and multi-select.
- Name collision handling across all supported extensions.
- File creation for `txt`, `md`, and `py`.
- Office package generation for `docx`, `xlsx`, and `pptx`.
- Action request encoding and decoding through shared models.
- Main app behavior when request data is missing or malformed.

Manual verification should cover:

- Finder menu item appears after enabling the extension.
- Finder's original context menu remains available.
- `New File...` opens the compact window.
- Created file appears in the expected directory.
- Created Office files can be opened by compatible macOS or Microsoft Office apps.

## Open Decisions

There are no open product decisions for version one. Later versions may add user-defined templates, more file formats, a settings screen for action modules, and non-Finder contexts.
