# FocusTime

A minimal, beautiful Pomodoro timer for macOS with Notion integration.

![FocusTime Logo](logo.png)

## Features

### Core Timer
- **Pomodoro Technique** - 25-minute work sessions with short and long breaks
- **Customizable durations** - Adjust work, short break, and long break times
- **Visual progress ring** - Clean circular progress indicator
- **Daily goal tracking** - Set and track your daily session target
- **Keyboard shortcut** - Global hotkey (⌘F) to start/pause timer

### Session Tagging
- **Tag your work** - Categorize sessions (Coding, Writing, Study, K8s, Homelab, etc.)
- **Custom tags** - Create your own tags with custom colors
- **Tag statistics** - See breakdown of time spent per category

### History & Analytics
- **Session history** - View past sessions by day
- **Heatmap view** - GitHub-style contribution heatmap of your focus time
- **Calendar view** - Browse sessions by date
- **Tag breakdown** - Pie chart showing time distribution

### Notion Integration
- **Automatic sync** - Sessions sync to Notion after completion
- **FocusTime Log database** - Daily entries with session count, tags, and focus time
- **Road to Mastery linking** - Automatically links to your daily tracking entries
- **Sync history** - Backfill all past sessions to Notion

### macOS Integration
- **Menu bar app** - Lives in your menu bar, always accessible
- **Focus Mode** - Automatically enables Do Not Disturb during work sessions
- **Launch at login** - Start automatically when you log in
- **Sound alerts** - Audio notification when sessions complete
- **Native notifications** - System notifications for session completion

## Screenshots

```
┌─────────────────────────┐
│       FocusTime         │
│                         │
│      ╭─────────╮        │
│     │  23:45   │        │
│      ╰─────────╯        │
│                         │
│   ● ● ● ○ ○  (3/5)     │
│                         │
│   [Start]  [Settings]   │
└─────────────────────────┘
```

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/FocusTime.git
   cd FocusTime
   ```

2. Open in Xcode:
   ```bash
   open FocusTime.xcodeproj
   ```

3. Build and run (⌘R)

### Enable Network Access (Required for Notion Sync)

1. In Xcode, select the project in the navigator
2. Select the "FocusTime" target
3. Go to **Signing & Capabilities** tab
4. Under **App Sandbox**, check **Outgoing Connections (Client)**

## Notion Setup

FocusTime can sync your sessions to a Notion database for tracking and analysis.

### 1. Create a Notion Integration

1. Go to [notion.so/my-integrations](https://www.notion.so/my-integrations)
2. Click **+ New integration**
3. Enter name: `FocusTime`
4. Select your workspace
5. Click **Submit**
6. Copy the **Internal Integration Token** (starts with `secret_...`)

### 2. Create FocusTime Log Database

Create a new database in Notion with these properties:

| Property | Type | Description |
|----------|------|-------------|
| Name | Title | Day name (e.g., "Thursday - Feb 27") |
| Date | Date | Session date |
| Sessions | Number | Total pomodoros completed |
| Tags | Text | Tag breakdown (e.g., "K8s (2), Coding (1)") |
| Focus Time | Text | Total time (e.g., "1h 15m") |
| Road to Mastery | Relation | Link to daily tracking (optional) |
| Notes | Text | Optional notes |

### 3. Share Database with Integration

1. Open your FocusTime Log database in Notion
2. Click **⋯** (three dots) at top right
3. Click **Connections** → **Connect to**
4. Select your **FocusTime** integration

### 4. Configure in App

1. Open FocusTime
2. Go to **Settings** → **Notion Sync** → **Configure**
3. Paste your API token
4. Click **Test Connection**
5. Enable sync

### 5. Update Database IDs (if needed)

The database IDs are configured in `NotionService.swift`:

```swift
static let databaseId = "your-focustime-log-database-id"
static let roadToMasteryDatabaseId = "your-road-to-mastery-database-id"
```

Get the ID from your Notion database URL:
```
https://www.notion.so/workspace/7d77e9fdc53b4d5099c9686741d250b4?v=...
                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                         This is the ID
```

## Usage

### Basic Timer

1. Click the FocusTime icon in your menu bar
2. Click **Start** to begin a 25-minute work session
3. When the timer completes, select a tag for your session
4. Take your break, then start another session

### Keyboard Shortcut

- **⌘F** - Toggle timer start/pause (global shortcut)

### Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Work | Work session duration | 25 min |
| Short Break | Short break duration | 5 min |
| Long Break | Long break duration (every 4 sessions) | 15 min |
| Daily Goal | Target sessions per day | 5 |
| Sound Alert | Play sound when session ends | On |
| Launch at Login | Start app when logging in | Off |
| Focus Mode | Enable Do Not Disturb during work | On |

### Tags

Default tags:
- 🟢 **Coding** - Programming and development
- 🔵 **Writing** - Documentation and content
- 🟠 **Study** - Learning and research
- 🟣 **Work** - General work tasks
- 🔵 **Reading** - Books and articles
- 🔵 **K8s** - Kubernetes and containers
- 🩷 **Homelab** - Home infrastructure
- ⚫ **Other** - Everything else

Add custom tags in **Settings** → **Manage Tags**.

## File Structure

```
FocusTime/
├── FocusTimeApp.swift      # App entry point, timer logic
├── ContentView.swift       # Main UI views
├── SessionHistory.swift    # Session storage and tag management
├── NotionService.swift     # Notion API integration
└── Assets.xcassets/        # App icons and colors
```

## Data Storage

Sessions are stored locally in UserDefaults:
- `sessionHistoryTagged` - Session data by date
- `savedTags_v3` - Custom tag definitions
- `notionApiKey` - Notion API token (stored securely)
- `notionSyncEnabled` - Sync preference

## Privacy

- All data is stored locally on your device
- Notion sync is optional and user-controlled
- No analytics or tracking
- No data sent to third parties

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by the [Pomodoro Technique](https://francescocirillo.com/products/the-pomodoro-technique) by Francesco Cirillo
- Built with SwiftUI for macOS
- Notion integration using the [Notion API](https://developers.notion.com/)

---

Made with ❤️ and lots of pomodoros 🍅
