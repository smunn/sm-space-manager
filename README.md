# SM Space Manager

A macOS menu bar app that auto-detects Spaces, names them by their window contents, and lets you switch between them.

## What It Does

- Detects all macOS Spaces across displays via Core Graphics private APIs
- Shows current space number in the menu bar
- Dropdown lists every space with auto-generated names and app lists
- Click a space to switch to it (uses arrow-key chaining — no "Switch to Desktop N" shortcuts required)
- Rename spaces manually; names persist across rearranges and reboots
- Auto-names spaces based on: Xcode project names, Cursor/VS Code folder names, terminal working directories, Chrome profile/page context

## Reference Project

Core space detection and switching code adapted from **[Spaceman](https://github.com/ruittenb/Spaceman)** by Sasindu Jayasinghe and René Uittenbogaard (MIT License). Spaceman solves the hard problems — private API bridging for space enumeration, handling ID reassignment on wake/reboot, and reading keyboard shortcuts from system prefs. This project builds on that foundation with auto-naming, window-to-space mapping, and a different UI approach.

Key Spaceman files referenced during development:
- `SpaceObserver.swift` — `CGSCopyManagedDisplaySpaces()` usage, multi-strategy ID matching
- `SpaceSwitcher.swift` — AppleScript keystroke simulation, chained arrow navigation
- `ShortcutHelper.swift` — reading `com.apple.symbolichotkeys` for desktop shortcuts
- `Space.swift` — space data model and switch index mapping

## Permissions Required

The app shows `+`/`-` status for each permission in the menu.

| Permission | Purpose | Required? |
|---|---|---|
| **Accessibility** | Simulate keyboard shortcuts to switch spaces | Yes |
| **Automation (System Events)** | Execute AppleScript keystrokes | Yes |
| **Screen Recording** | Read window titles from other apps (`kCGWindowName`) | Yes, for auto-naming |

**Important:** After granting Screen Recording, you must quit and relaunch the app. If permissions show `-` after granting, the app's code signature may have changed (e.g., after a rebuild). Run `tccutil reset Accessibility com.smunn.SpaceManager && tccutil reset ScreenCapture com.smunn.SpaceManager && tccutil reset AppleEvents com.smunn.SpaceManager` then re-grant.

## Architecture

```
SpaceManager/
├── App/
│   ├── SpaceManagerApp.swift          # @main SwiftUI entry
│   └── AppDelegate.swift              # Orchestrates subsystems
├── Core/
│   ├── SpaceObserver.swift            # Space detection (CGSCopyManagedDisplaySpaces)
│   ├── SpaceSwitcher.swift            # Space switching (AppleScript + arrow chaining)
│   ├── ShortcutHelper.swift           # Reads keyboard shortcuts from macOS prefs
│   ├── WindowDetector.swift           # Maps windows to spaces via CGWindowListCopyWindowInfo
│   ├── SpaceNamer.swift               # Auto-naming from window titles + process CWDs
│   └── DisplayGeometryUtilities.swift # Multi-display ordering
├── Models/
│   ├── Space.swift                    # Space data model
│   ├── SpaceWindow.swift              # Window info (app, title, PID, bounds)
│   ├── SpaceNameInfo.swift            # Persisted name + override flag
│   └── DisplayDirection.swift         # Display sort enums
├── Views/
│   └── StatusBarController.swift      # NSMenu-based menu bar UI
├── Utilities/
│   ├── SpaceNameStore.swift           # UserDefaults persistence
│   ├── ProcessHelper.swift            # Terminal shell CWD resolution (async + cached)
│   └── Extensions.swift
├── Resources/
│   ├── Info.plist
│   ├── SpaceManager.entitlements
│   └── Assets.xcassets/
└── SpaceManager-Bridging-Header.h     # Private CG API declarations
```

## How It Works

### Space Detection
Uses `CGSCopyManagedDisplaySpaces()` (private Core Graphics API declared in the bridging header) to enumerate all spaces. Handles three scenarios with different matching strategies:
- **Normal operation** — ID-based matching tracks user rearranges
- **Wake/reboot** — position-based matching handles macOS ID reassignment
- **Display topology change** — ID-first with position fallback

### Window-to-Space Mapping
`CGWindowListCopyWindowInfo(.optionOnScreenOnly)` snapshots visible windows when a space becomes active. The mapping builds up over time as you visit spaces. Only the current space's windows are known on first launch.

### Auto-Naming Priority
1. Xcode project name (parsed from "ProjectName — file.swift" window title)
2. Cursor / VS Code folder name (parsed from "file — FolderName" title)
3. Terminal CWD (resolved via process tree: `pgrep` child PIDs + `lsof` for CWD)
4. Chrome profile name (parsed from "Page - Profile - Google Chrome" title)
5. Dominant app name if single app
6. Top 2 app names
7. "Space N" fallback

### Space Switching
Reads macOS keyboard shortcuts from `com.apple.symbolichotkeys`. If "Switch to Desktop N" shortcuts are configured (IDs 118–132), uses direct switching. Otherwise falls back to arrow-key chaining — sends Ctrl+Left/Right repeatedly, waiting for `activeSpaceDidChangeNotification` between each step.

### Name Persistence
User-overridden names are stored in UserDefaults keyed by macOS space ID (`ManagedSpaceID`). The `isUserOverride` flag distinguishes manual names from auto-generated ones. Clearing an override reverts to auto-detection.

## Build & Deploy

Requires [xcodegen](https://github.com/yonaskolb/XcodeGen) to regenerate the Xcode project from `project.yml`.

```bash
# Generate Xcode project (after modifying project.yml or adding files)
xcodegen generate

# Build and deploy to /Applications
npm run deploy

# The deploy script:
# 1. Builds Release config with local derivedDataPath
# 2. Kills running instance
# 3. Copies .app to /Applications
# 4. Launches the app
```

The app is signed with `Apple Development: Scott Munn` to maintain a stable code signature across rebuilds, preserving macOS permission grants.

## Known Limitations

- Window titles require Screen Recording permission — without it, only generic app names are available
- Terminal CWD detection works best with single-window terminal apps; Terminal.app shares one PID across all windows, so CWD resolution may return any shell's directory
- Window mapping only knows spaces you've visited since launch
- No "Switch to Desktop N" shortcuts configured by default on macOS — the app uses arrow-key chaining which is slightly slower for distant spaces

## License

MIT — see [LICENSE](LICENSE). Portions adapted from [Spaceman](https://github.com/ruittenb/Spaceman) (MIT).
