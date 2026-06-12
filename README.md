# MacCleaner

A personal CleanMyMac-style utility for macOS, built with SwiftUI. No accounts,
no subscriptions — just the cleaning tools.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange)

## Features

### Cleanup
- **Smart Scan** — one-click parallel scan across all junk categories with a
  progress ring, size breakdown, and one-button cleanup.
- **System Junk** — per-item review of user caches, logs & diagnostics, Xcode
  junk, dev package caches (npm, pip, Cargo, Gradle, CocoaPods), Mail
  attachments, old Desktop screenshots, Trash contents, and old installers.
  Categories carry **SAFE / REVIEW** badges; a cache-age rule (Settings) can
  restrict flagging to caches untouched for 7/30/90 days.
- **Privacy** — per-browser caches, history, and cookies for Safari, Chrome,
  Arc, Brave, Edge, and Firefox. Detects running browsers and offers to quit
  them before cleaning.

### Speed
- **Maintenance** — free RAM, flush DNS, reindex Spotlight, rebuild Launch
  Services, run periodic scripts, clear Time Machine local snapshots, empty
  Trash. Admin tasks use the system authorization dialog.
- **Optimization** — live top CPU/memory consumers with one-click Quit, plus a
  launch-agent manager (enable/disable login background helpers).

### Files
- **Large & Old Files** — biggest files in your home folder with a size
  threshold and last-accessed dates.
- **Duplicates** — content-identical files found via size → partial-hash →
  full-hash passes. Keep-newest/keep-oldest auto-selection; one copy of every
  file is always preserved.
- **Space Lens** — squarified **treemap** of disk usage (click tiles to drill
  in) with a list fallback.

### Always on
- **Menu bar companion** — live storage/memory/CPU gauges, junk-scan status,
  Free Up RAM, all without opening the window.
- **Scheduled scan** — optional weekly background junk scan (launchd agent via
  `SMAppService`) that posts a notification with the junk total.
- **History & Undo** — every cleanup is logged (lifetime total included), and
  trash-based cleanups can be **restored** straight out of the Trash.

## Safety model

- Cleanups default to **moving items to the Trash** (recoverable); History can
  restore them. Items already in the Trash are deleted permanently.
- Duplicates always keeps at least one copy per set; Apple's own apps are
  hidden from the Uninstaller; running browsers are never cleaned.
- An exclusions list (Settings → Exclusions) keeps chosen paths off-limits.
- Destructive actions ask for confirmation.

## Build & run

```sh
./Scripts/build-app.sh   # release build → MacCleaner.app in the repo root
open MacCleaner.app
swift test               # run the test suite
```

For development, `swift run` works too. Note the scheduled-scan toggle needs
the bundled app (the launch agent lives in `Contents/Library/LaunchAgents`).
The headless scan can be tested with `MacCleaner --background-scan`.

> **First run:** macOS will prompt for folder access as scanners touch
> protected folders. For full coverage (Safari data, Mail attachments), grant
> **Full Disk Access** — the Smart Scan banner and Settings → Permissions link
> straight to the right pane.

## Layout

```
Sources/MacCleaner/
├── App/        entry point (window + menu bar + Settings scenes), sidebar
├── Models/     value types + @Observable feature models, settings, history
├── Services/   scanners and system operations (no UI)
├── Utilities/  formatting, file sizing, shell helpers, treemap layout
└── Views/      SwiftUI feature views
Tests/          scanner + layout + history unit tests
Scripts/        app bundling, Info.plist, icon generator, launch agent plist
```
