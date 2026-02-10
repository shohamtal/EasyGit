# EasyGit

A native macOS Git GUI built with SwiftUI. Manage your repositories, stage files, view diffs, and commit — all from a clean three-panel interface.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Repository Management** — Add repos individually, scan directories, or import VS Code `.code-workspace` files
- **Three-Panel Layout** — Sidebar (repos), changes panel (staged/unstaged files), diff viewer
- **Inline Diff Viewer** — Side-by-side line numbers, colored additions/deletions, line-level staging via drag selection
- **Branch Operations** — Switch branches, create new branches, prune stale remote branches
- **Commit & Push** — Commit to current branch, push (auto-sets upstream), pull
- **Create PR** — Opens GitHub/Bitbucket PR creation page for the current branch
- **Built-in Terminal** — Resizable terminal panel with command input, history (up/down arrows), output logging
- **Safety Features** — Protected branch commit confirmation, sensitive data detection before push
- **Multiple Themes** — Dark, Light, Light Blue, and Glitter (purple glow)
- **File Watcher** — Auto-refreshes when files change on disk

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ / Xcode 15+
- Git installed at `/usr/bin/git`

## Building

### From Terminal (SPM)

```bash
cd EasyGit
swift build -c release
```

The binary will be at `.build/arm64-apple-macosx/release/EasyGit` (Apple Silicon) or `.build/x86_64-apple-macosx/release/EasyGit` (Intel).

### Creating the .app Bundle

After building, create the app bundle:

```bash
# Build release binary
cd EasyGit
swift build -c release

# Create .app structure
mkdir -p ../EasyGit.app/Contents/MacOS
mkdir -p ../EasyGit.app/Contents/Resources

# Copy binary (adjust path for your architecture)
cp .build/arm64-apple-macosx/release/EasyGit ../EasyGit.app/Contents/MacOS/
chmod +x ../EasyGit.app/Contents/MacOS/EasyGit
```

The `Info.plist` is already included at `EasyGit.app/Contents/Info.plist`.

### Running

Double-click `EasyGit.app` or run directly:

```bash
./EasyGit.app/Contents/MacOS/EasyGit
```

Or run without bundling:

```bash
cd EasyGit
swift run
```

## Project Structure

```
EasyGit/
├── Package.swift
└── Sources/EasyGit/
    ├── GitDeskApp.swift          # App entry point
    ├── Models/                   # Data models (Repository, GitFileChange, DiffModels, etc.)
    ├── Services/                 # Git CLI wrapper, diff/status parsers, file watcher
    ├── ViewModels/               # App, Changes, Diff, Commit, Log view models
    ├── Views/
    │   ├── MainContentView.swift # Root layout
    │   ├── Header/               # Branch picker, toolbar buttons
    │   ├── Sidebar/              # Repository list, add repo sheet
    │   ├── Changes/              # Staged/unstaged file lists
    │   ├── DiffViewer/           # Diff panel with line-level selection
    │   ├── CommitArea/           # Commit message + action buttons
    │   └── Footer/               # Status bar, terminal panel
    └── Utilities/                # Theme system, UserDefaults storage
```

## Usage

1. Launch the app
2. Click **+** in the sidebar to add a repository (folder, parent directory, or `.code-workspace`)
3. Select a repo to see its changed files
4. Click files to view diffs
5. Check/uncheck files to stage/unstage, or drag-select diff lines for partial staging
6. Enter a commit message and click **Commit**
7. Use **Push** / **Pull** buttons or the built-in terminal for any git command

## Credits

Created by [Shoham Tal](https://github.com/shohamtal) and [Claude](https://claude.ai) (Anthropic).

## License

[MIT](LICENSE)
