# EasyGit

**The Git GUI that gets out of your way.** A lightweight, native macOS app for everyday Git workflows — stage, diff, commit, push, all without leaving a single window.

No Electron. No Java. No 500MB download. Just a fast, native SwiftUI app that launches instantly and does exactly what you need.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

https://github.com/user-attachments/assets/ca499dc3-2472-4388-8b9d-6e0995d9a9d7

---

## Why EasyGit?

Most Git GUIs are either too bloated or too basic. EasyGit is built for developers who want a **visual overview** of their repos without giving up the speed and control of the terminal.

- **Zero config** — Drop in your repo folder and start working. Supports single repos, directories of repos, and VS Code `.code-workspace` files.
- **One-window workflow** — See your files, diffs, and commit area all at once in a resizable three-panel layout.
- **Built-in terminal** — Need to run a quick `git rebase` or `npm install`? Type it right in the app. No context switching.
- **Lightweight** — Native SwiftUI app, ~5MB binary. Launches in under a second.

---

## Features

### Repository Management
Add a single repo, point to a parent directory to import all repos inside it, or drag in a VS Code `.code-workspace` file to import an entire workspace at once. Repos are organized into collapsible groups in the sidebar. Remembers your last selected repo between sessions.

### Visual Staging with Full Diffs
See all your changed files at a glance — unstaged on top, staged on bottom. Click any file to see its full diff with colored line-by-line additions and deletions. Stage or unstage entire files with a checkbox, or **drag-select specific lines** in the diff for partial staging.

### One-Click Branch Operations
Switch branches, create new ones, push, pull, and prune — all from the toolbar. Push auto-detects new branches and sets upstream automatically. Prune finds local branches whose remote was deleted and offers to clean them up with a confirmation dialog.

### Create Pull Requests Instantly
Click **Create PR** and EasyGit opens the correct GitHub or Bitbucket PR creation page for your current branch. Supports both platforms automatically by reading your remote URL.

### Built-in Terminal
A resizable terminal panel slides up from the bottom. Run any command — git or otherwise — directly in your repo's directory. Command history with up/down arrows. Output from both the terminal and app operations (push, pull, prune) streams into the same log, so you always know what happened.

### Safety Guardrails
- **Protected branch warning** — Committing to `main`, `master`, `develop`, `staging`, `production`, or `release/*`? A confirmation dialog makes sure you meant to.
- **Sensitive data detection** — Before pushing, EasyGit scans your unpushed commits for hardcoded passwords, API keys, AWS credentials, private keys, tokens, and other secrets. If anything is found, you'll see exactly what and where before it goes to the remote.

### Themes
Four built-in themes: **Dark**, **Light**, **Light Blue**, and **Glitter** (a purple neon glow theme). Switch instantly from the toolbar.

### Resizable Everything
Every panel border is draggable — sidebar width, changes panel width, unstaged/staged split, diff/commit split, terminal height. Make the layout work for your screen.

### Live File Watching
EasyGit watches your repo directory for changes. Edit a file in your editor, and the changes panel updates automatically — no manual refresh needed.

---

## Install

### Homebrew (recommended)

```bash
brew tap shohamtal/easygit
brew install --cask easygit
```

### Manual Download

Grab the latest `EasyGit.zip` from the [Releases](../../releases) page. Unzip and double-click `EasyGit.app` to run.

### Update

```bash
brew upgrade --cask easygit
```

### Uninstall

```bash
brew uninstall --cask easygit
```

## Requirements

- macOS 14 (Sonoma) or later
- Git installed at `/usr/bin/git`

## Building from Source

If you prefer to build it yourself, you'll need Swift 5.9+ / Xcode 15+.

### Quick Build (recommended)

```bash
./build.sh
```

This compiles the project and creates `EasyGit.app` ready to run.

### Manual Build

```bash
cd EasyGit
swift build -c release
```

The binary will be at `.build/arm64-apple-macosx/release/EasyGit` (Apple Silicon) or `.build/x86_64-apple-macosx/release/EasyGit` (Intel).

### Running

Double-click `EasyGit.app`, or run directly:

```bash
open EasyGit.app
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
7. Use **Push** / **Pull** in the toolbar, or open the terminal for any command

## Credits

Created by [Shoham Tal](https://github.com/shohamtal) and [Claude](https://claude.ai) (Anthropic).

## License

[MIT](LICENSE)
