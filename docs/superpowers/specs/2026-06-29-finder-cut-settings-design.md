# Finder Cut And Settings Design

Date: 2026-06-29

## Summary

RightClick should expand from a single `New File...` Finder action into a small configurable Finder action utility. This iteration adds two user-facing changes:

- Broaden the Finder Sync extension's watched locations so the menu is more likely to appear on Desktop, iCloud Drive, network volumes, shared locations, and mounted volumes.
- Add a Windows-style file `Cut` and `Paste` flow, controlled by a settings window where the user can enable or disable action modules.

The project remains source-distributed and locally signed. The design avoids App Groups because the app is intended to work without a paid Apple Developer account.

## Goals

- Keep Finder's original context menu intact.
- Keep `New File...` available as an optional action.
- Add `Cut` for selected Finder items.
- Add `Paste` for moving previously cut items into the current Finder location.
- Add app settings for enabling or disabling action modules.
- Make settings changes visible to the Finder extension on the next menu build.
- Add a user-triggered Finder restart command for cases where Finder Sync caches menu state.
- Expand watched directories to cover common personal, iCloud, mounted-volume, network-volume, and shared locations as much as Finder Sync allows.

## Non-Goals

- Replacing Finder's native copy, paste, move, or trash behavior.
- Implementing clipboard integration with Finder's private pasteboard formats.
- Supporting cross-device or cloud-synced cut state.
- Supporting undo for moved files in this iteration.
- Guaranteeing menu visibility in every network or shared location. Finder Sync may still limit extension behavior for some providers.
- Adding a fully customizable action builder.

## Watched Location Design

The extension currently watches `/`, which is broad but not always enough in practice for Finder Sync behavior on special providers. This iteration should use a generated watched-location list instead of a single hard-coded URL.

Default watched locations:

- `/`
- The current user's home directory
- `~/Desktop`
- `~/Documents`
- `~/Downloads`
- `~/Library/Mobile Documents`
- `~/Library/CloudStorage`
- `/Volumes`
- Existing mounted volume roots under `/Volumes`

The list should be built defensively:

- Expand `~` at runtime.
- Include only paths that currently exist.
- De-duplicate URLs.
- Keep `/` first so ordinary local folders stay covered.
- Rebuild the list when the extension initializes.

This does not make a hard guarantee for every provider. The README should explain that Finder Sync visibility can still depend on Finder, mounted volume type, cloud provider behavior, and macOS privacy restrictions.

## Settings Design

The main app adds a settings window or settings section with two module toggles:

- `New File`
- `Cut / Paste`

Default settings:

- `New File`: enabled
- `Cut / Paste`: disabled

The safer default keeps the existing behavior available while preventing a move operation from appearing until the user intentionally enables it.

The settings UI also includes a `Restart Finder` command. The command is not required for every settings change, but gives the user a reliable way to refresh Finder Sync if Finder has cached the menu.

## Settings Persistence

Settings should be stored in a JSON file that both the main app and Finder extension can read:

```text
~/Library/Application Support/RightClick/settings.json
```

Use a shared `SettingsStore` in `RightClickCore`.

Requirements:

- Create the Application Support directory when saving settings.
- If the file does not exist, return default settings.
- If the file is malformed, return default settings and avoid crashing the extension.
- Save settings atomically where possible.
- The Finder extension must read settings each time `menu(for:)` is called, not only at extension startup.

This ensures settings are normally reflected on the next right-click menu. If Finder caches the extension menu, the user can use `Restart Finder`.

## Finder Menu Design

The Finder extension builds its menu from enabled modules and current Finder context.

Rules:

- If `New File` is enabled, show `New File...`.
- If `Cut / Paste` is enabled and Finder has selected items, show `Cut`.
- If `Cut / Paste` is enabled and there is a stored cut state, show `Paste`.
- If no actions are available, return an empty custom menu rather than adding disabled noise.

Menu titles use native plain Finder-style names:

- `New File...`
- `Cut`
- `Paste`

This version does not add icons or nested submenus.

## Cut State Design

Cut state should be stored in another JSON file under Application Support:

```text
~/Library/Application Support/RightClick/cut-state.json
```

Use a shared `CutStateStore` in `RightClickCore`.

Stored data:

- A unique operation id.
- Creation timestamp.
- List of selected item URLs.

`Cut` behavior:

- Requires at least one selected Finder item.
- Stores the selected file and folder URLs.
- Replaces any previous cut state.
- Does not move files yet.

`Paste` behavior:

- Resolves the target directory from the current Finder context.
- Moves each stored item into that directory.
- Uses a collision resolver so existing target names are not overwritten.
- Clears cut state only after all moves succeed.
- Reveals or refreshes the target directory if possible.

The first implementation should keep move behavior conservative. If any move fails, the operation reports the error and leaves the cut state intact so the user can retry or clear it later.

## Main App Routing

The app currently opens `NewFileView` from a `rightclick://new-file` URL. This iteration adds URL routes:

- `rightclick://new-file?request=...`
- `rightclick://cut?request=...`
- `rightclick://paste?request=...`

`new-file` opens the existing compact creation window.

`cut` can be handled without showing a window. It stores cut state and then quits the helper app.

`paste` can also run without a normal window. It performs the move and quits on success. If an error occurs, the app should show a compact native error window so the failure is visible.

## Error Handling

User-visible errors should cover:

- No selected items for `Cut`.
- Missing target directory for `Paste`.
- Source item no longer exists.
- Target directory unavailable.
- Move failed because of permissions, volume behavior, or provider restrictions.
- Collision resolver could not find a safe destination name.
- Malformed settings or cut-state files.

The Finder extension should not present complex UI. It should log failures and route action execution to the main app where errors can be shown.

## Testing

Core tests should cover:

- Default settings when no settings file exists.
- Saving and loading settings.
- Malformed settings fallback.
- Cut state save, load, replace, and clear.
- Paste target resolution using existing `TargetDirectoryResolver`.
- Move behavior for files.
- Move behavior for folders.
- Name collision behavior during paste.
- Failed move keeps cut state.
- Watched location builder de-duplicates and filters missing paths.

Manual verification should cover:

- Desktop shows enabled RightClick menu items.
- iCloud Drive shows enabled RightClick menu items where Finder Sync allows.
- Mounted volume or network share shows enabled RightClick menu items where Finder Sync allows.
- Disabling `New File` hides `New File...`.
- Enabling `Cut / Paste` shows `Cut` when files are selected.
- `Paste` appears after cutting items.
- `Paste` moves files into the right-click target directory.
- Restart Finder refreshes menu visibility after settings changes.

## Documentation Updates

README should be updated with:

- Settings usage.
- Explanation that settings normally apply on the next right-click.
- `Restart Finder` troubleshooting guidance.
- Finder Sync coverage caveat for iCloud, network volumes, shared locations, and mounted volumes.
- Warning that `Cut / Paste` moves files and is disabled by default.
