# Tasks+ : Google Tasks, Supercharged

A native macOS app that enhances Google Tasks with tag-based filtering, search, and a modern UI.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Why Tasks+?

Google Tasks is great for simple task management, but lacks powerful organization features. Tasks+ uses Google Tasks as its backend while adding capabilities that Google doesn't offer:

- **Tag-based filtering** — Add `#hashtags` to task descriptions and filter/search by them
- **Cross-list search** — Search across all your task lists at once
- **Rich task cards** — See descriptions, tags, dates, and list names at a glance
- **Expandable descriptions** — Preview or expand full task details inline
- **Clickable URLs** — Links in descriptions open directly in your browser
- **Sorting controls** — Sort by date or name, ascending or descending

All changes sync bidirectionally with Google Tasks in real time.

## Tasks+ vs Google Tasks

| Feature | Google Tasks | Tasks+ |
|---------|:-----------:|:------:|
| Create, edit, complete tasks | Yes | Yes |
| Multiple task lists | Yes | Yes |
| Due dates | Yes | Yes |
| Task descriptions | Yes | Yes |
| **Tag / hashtag support** | No | Yes |
| **Filter by tags** | No | Yes |
| **Search across all lists** | No | Yes |
| **Search by `#tag`** | No | Yes |
| **Multi-tag filtering (OR)** | No | Yes |
| **Sort by name or date** | No | Yes |
| **Sort ascending / descending** | No | Yes |
| **Expandable task descriptions inline** | No | Yes |
| **Clickable URLs in descriptions** | No | Yes |
| **Show/hide completed tasks toggle** | Partial (per list) | Yes (global) |
| **Cross-list task view** | No | Yes |
| **Updated timestamp visible** | No | Yes |
| **Completed timestamp visible** | No | Yes |
| **Flow-wrapped list/tag chips** | N/A | Yes |
| **Keyboard shortcuts** | Limited | `Cmd+N`, `Cmd+R`, `Cmd+Return` |
| **Optimistic UI updates** | N/A | Yes (instant toggle) |
| **Desktop native app (macOS)** | Web/mobile only | Yes |
| Full offline support | Mobile only | No (requires API) |
| Subtasks | Yes | Not yet |
| Recurring tasks | Yes | Not yet |

Tasks+ is designed as a **companion**, not a replacement. Both apps read and write to the same Google Tasks data — you can use Tasks+ on your Mac and Google Tasks on your phone seamlessly.

## Screenshots

| Task List | Tag Filtering | New Task |
|-----------|--------------|----------|
| Clean card layout with metadata | Flow-wrapped tag chips | Full form with tag selector |

## Features

### Tag System
Tasks+ parses standard `#hashtag` format tags from Google Task descriptions. Since Google Tasks has no native tag field, tags are stored at the bottom of the description and are fully compatible with the Google Tasks mobile and web apps.

- Tags are extracted using the pattern `#word`, `#word-with-dashes`, `#word_underscores`
- Filter by multiple tags simultaneously (OR logic)
- Create new tags or select existing ones when creating/editing tasks
- Search with `#tag` prefix for tag-specific search

### Task Management
- **Create tasks** — Full form with title, list picker, due date, description, and tag selector (`Cmd+N`)
- **Edit tasks** — Double-click any task to edit all fields, with updated/completed timestamps shown
- **Complete tasks** — Optimistic UI updates instantly; syncs to Google Tasks API in background
- **Expand/collapse** — "More/Less" button on each card to view full descriptions inline

### Organization
- **List filtering** — Filter by any Google Task list, with flow-wrapped chips
- **Tag filtering** — Multi-select tag chips, with "Clear" to reset
- **Sorting** — Sort by Date (newest/oldest first) or Name (A-Z / Z-A)
- **Show/hide completed** — Toggle completed tasks visibility (hidden by default)
- **Search** — Free text search across titles, descriptions, and tags
- **Pull to refresh** — `Cmd+R` to sync from Google Tasks

### UI
- Custom color scheme (red accent `#FF3621`, dark nav `#1B3139`, clean white surfaces)
- Flow layout for tags and lists — chips wrap to fit window width, no horizontal scrolling
- Clickable URLs in task descriptions open in default browser
- Custom app icon with checkmark + tag motif

## Requirements

- macOS 14.0 (Sonoma) or later
- Google Cloud project with Tasks API enabled
- `gcloud` CLI authenticated with Google Tasks scope

## Setup

### 1. Google Cloud Authentication

Tasks+ uses your existing `gcloud` application-default credentials. If you already have gcloud configured with Tasks API scope, skip to step 3.

```bash
# Install gcloud if needed
brew install --cask google-cloud-sdk

# Authenticate with Tasks scope
gcloud auth application-default login \
  --scopes="https://www.googleapis.com/auth/tasks"
```

### 2. Enable Google Tasks API

```bash
gcloud services enable tasks.googleapis.com --project=YOUR_PROJECT_ID
```

### 3. Configure the App

Edit `GoogleTasksPlus/Config.swift` and set your GCP project ID for quota:

```swift
static let quotaProject = "your-gcp-project-id"
```

Also update the path to your token helper script, or replace the auth mechanism with your own gcloud token source:

```swift
static let googleAuthScript = "/path/to/your/google_auth.py"
```

### 4. Build and Run

```bash
# Clone
git clone https://github.com/wscalioni/google-tasks-plus.git
cd google-tasks-plus

# Build
xcodebuild -project GoogleTasksPlus.xcodeproj \
  -scheme GoogleTasksPlus \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

# Run
open $(xcodebuild -project GoogleTasksPlus.xcodeproj \
  -scheme GoogleTasksPlus \
  -destination 'platform=macOS' \
  -showBuildSettings 2>/dev/null | \
  grep -m1 'BUILT_PRODUCTS_DIR' | \
  awk '{print $3}')/GoogleTasksPlus.app
```

Or open `GoogleTasksPlus.xcodeproj` in Xcode and press `Cmd+R`.

## Project Structure

```
GoogleTasksPlus/
├── GoogleTasksPlusApp.swift    # App entry point, window configuration
├── Config.swift                # GCP project & API configuration
├── Theme.swift                 # Color palette (DB.red, DB.navBackground, etc.)
├── TaskModel.swift             # Google Tasks API + app data models
├── TagParser.swift             # Regex-based #hashtag extraction
├── NotesHelper.swift           # Compose notes with tags appended
├── GoogleAuthService.swift     # gcloud credential management
├── GoogleTasksService.swift    # Tasks API: fetch, create, update, toggle
├── ContentView.swift           # Auth gate (sign-in vs main view)
├── MainTasksView.swift         # Main screen: header, filters, task list
├── TaskRowView.swift           # Task card with expand, tags, links
├── TaskFormView.swift          # Shared form for create/edit
├── NewTaskView.swift           # New task dialog
├── EditTaskView.swift          # Edit task dialog
├── TagChip.swift               # Tag and list filter chip components
├── FlowLayout.swift            # Wrapping layout for chips
├── LinkedText.swift            # URL detection and clickable links
└── Assets.xcassets/            # App icon and colors
```

## How Tags Work

Since Google Tasks doesn't have a dedicated tags field, Tasks+ stores tags in the task description:

```
This is my task description with details about what needs to be done.

#automation #in-progress #frontend
```

When creating or editing a task, selected tags are automatically appended to the bottom of the description. When reading tasks, the tag parser extracts them and displays them as interactive chips — the description shown in the UI has tags stripped out for cleanliness.

This approach means tags are fully visible and editable in the Google Tasks mobile/web app as well.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New task |
| `Cmd+R` | Refresh tasks |
| `Cmd+Return` | Save (in create/edit dialog) |
| `Esc` | Cancel dialog |
| Double-click | Edit task |

## License

MIT

## Acknowledgments

- Built with SwiftUI and SpriteKit
- Uses Google Tasks REST API
- Custom-designed UI theme
- AI-assisted development by Claude Code
