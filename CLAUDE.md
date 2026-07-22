# FocusTime — Notes for Claude

A macOS menu-bar Pomodoro timer (SwiftUI, ~3.7 KLOC), single active developer,
with tag-based session tracking, history visualizations, and one-way sync to
a personal Notion workspace.

- **Repo root / Xcode project**: this directory (`FocusTime.xcodeproj`)
- **Remote**: `origin` → `https://github.com/guyfromtheke/FocusTime.git`
- **Deployment target**: macOS 13.0+, `SUPPORTED_PLATFORMS = macosx` only (not iOS/visionOS)
- **Bundle ID**: `guyfromtheke.FocusTime`

## Building & running

```bash
# Debug build + launch (also usable via ./bin/focus --dev open)
xcodebuild -project FocusTime.xcodeproj -scheme FocusTime -configuration Debug \
  -derivedDataPath /tmp/FocusTime-xcodebuild build
open /tmp/FocusTime-xcodebuild/Build/Products/Debug/FocusTime.app

# Standalone install to /Applications (Release)
xcodebuild -project FocusTime.xcodeproj -scheme FocusTime -configuration Release \
  -derivedDataPath /tmp/FocusTime-release build
rm -rf /Applications/FocusTime.app
cp -R /tmp/FocusTime-release/Build/Products/Release/FocusTime.app /Applications/FocusTime.app
```

`bin/focus [open|start|pause|toggle|reset|switch|status] [--dev|--build]` is a CLI bridge
that talks to the running app via a shared `UserDefaults` suite (`guyfromtheke.FocusTime`)
polled every 0.5s by `TerminalCommandCenter` in `FocusTimeApp.swift`. It prefers an
installed `/Applications/FocusTime.app`; `--dev` forces the `/tmp` dev build.

There is no test target and no CI. Verification in this repo has been: build with
`xcodebuild`, launch the real app, drive it via `bin/focus`, and read `os.Logger`
output with `log show --predicate 'process CONTAINS "FocusTime"'` (note: on this
machine `log` was shadowed by a shell alias/function — use `/usr/bin/log` directly
if `log show` errors with "too many arguments").

## Architecture

- `FocusTimeApp.swift` — app entry point, `TimerState` (published timer/session state),
  `FocusModeManager`, `HotkeyManager` (Carbon global hotkey, ⌘⇧F), `TerminalCommandCenter`
  (CLI bridge), `AppDelegate`. This is where the actual timer tick loop and session
  completion flow live.
- `ContentView.swift` + `ContentView+{Settings,History,Calendar,Notion,TagManager}.swift` —
  UI, split by screen (already refactored from a single 1,257-line god view).
- `SessionHistory.swift` — local session/tag store (`UserDefaults`-backed JSON),
  streaks, backup/export/import, Notion sync triggering, pending-sync retry queue.
- `NotionService.swift` — Notion API client. Token in Keychain (`KeychainStore`),
  database IDs are user-configurable in Settings (not hardcoded).
- `PlannerSync.swift` — pushes a JSON snapshot of history/tags/workMinutes/dailyGoal
  to a shared location for an external homelab "Glance" planner integration.
- `HeatmapView.swift`, `PieSlice.swift` — history visualizations.
- `AppLog.swift` — `os.Logger` wrappers (`AppLog.app`, `AppLog.notion`); no `print()` in the codebase.

## Things fixed recently (read before "fixing" them again)

1. **App is `LSUIElement = YES`** (`project.pbxproj`, both Debug/Release configs).
   No Dock icon, `WindowGroup` does not auto-open a window at launch — the
   `MenuBarExtra` icon is the only entry point unless you call `showMainWindow()`
   or use the hotkey / `bin/focus open`. Don't remove this key without discussing
   it — restoring it is exactly what made the app "not pin to the menu bar" (it
   was showing as a normal windowed app with a Dock icon instead).

2. **Timer is wall-clock-anchored, not tick-decremented.** `TimerState.endDate`
   holds an absolute end time; each 1s `Timer` tick recomputes
   `timeRemaining = Int(ceil(endDate.timeIntervalSinceNow))`. This was a real bug:
   naively decrementing `timeRemaining -= 1` per tick drifts whenever the Mac
   sleeps (the `Timer` doesn't fire during sleep, but real time keeps moving).
   If you touch `startTimer()`/`finishInterval()`, preserve this pattern.

3. **Focus Mode is `shortcuts run "Start Focus"` / `"Stop Focus"`** (`FocusModeManager`
   in `FocusTimeApp.swift`), run off the main thread, with exit status checked.
   There used to be an AppleScript fallback toggling
   `com.apple.notificationcenterui doNotDisturb` directly — removed, because that
   key stopped being honored by Notification Center on macOS Monterey+, so it
   silently did nothing. Failures now set `timerState.focusModeWarning`, shown
   under the Focus Mode toggle in Settings. **This requires the user to have
   created Shortcuts literally named "Start Focus" and "Stop Focus"** — it is not
   something FocusTime can provision itself.

4. **Focus Mode showing up on other devices (e.g. iPhone) is expected, not a bug.**
   It's Apple's Focus "Share Across Devices" continuity feature syncing whatever
   system Focus the Shortcut triggers. Not controllable from this app; user-side
   fix is in `Settings → Focus → Share Across Devices` on each device.

5. **Session-completion notification could get silently swallowed** by the user's
   own still-active Focus/DND, because it used to fire immediately while
   `disableFocus` was still running asynchronously in the background. Fixed via
   `finishInterval()` in `FocusTimeApp.swift`, which now chains
   `notifyAndAdvance()` off the `disableFocus` completion so Focus is confirmed
   off (or confirmed failed, with a warning) before the sound/notification fires.

6. **`finishInterval()` also calls `showMainWindow()`** when a *work* session ends
   (not breaks), so the tag picker isn't stuck invisible behind the menu bar icon.

7. **`SessionHistory.updateTag(oldName:newName:newColorHex:)` now returns `Bool`**
   and rejects renames that collide with an existing tag name (mirrors the check
   `addCustomTag` already had). Before this, renaming a tag to match another
   existing tag silently created two `SessionTag`s with the same name, and
   `history` entries became ambiguous since sessions are keyed by tag name, not
   id. `ContentView+TagManager.swift` surfaces the failure as inline red text.

8. **App icon**: custom artwork (tomato/hourglass) in `Assets.xcassets/AppIcon.appiconset/`,
   generated via ChatGPT Images and resized with `sips` into the sizes
   `Contents.json` expects (16/32/64/128/256/512/1024, with `32 1.png`/`256 1.png`/
   `512 1.png` as duplicate-content 1x/2x slot filenames — don't be surprised by that).
   There's also a separate `Assets.xcassets/MenuBarIcon.imageset` — a monochrome
   silhouette derived from the same artwork (luminance-thresholded, since the glyph
   is white/cream on a red gradient), marked `template-rendering-intent: template`,
   used by the `MenuBarExtra` label instead of the generic SF Symbol `"timer"`
   (which reads as a gauge/speedometer at menu-bar size). If regenerating: extract
   the glyph via a luminance threshold (~200/255), crop to its bounding box with
   ~18% padding, square-pad, export at 18/36/54px.

9. **A completed work session is recorded immediately** (`finishInterval()` in
   `FocusTimeApp.swift`), synchronously, tagged `"Other"`, *before* the async
   Focus Mode / notification chain runs. The tag picker calls
   `SessionHistory.relabelSession(dateKey:from:to:)` to retag that placeholder
   once the user actually picks a tag — it no longer creates the record itself
   (`TimerState.pendingTagDateKey` tracks which day's placeholder to relabel).
   Previously the session was only ever recorded when a tag was picked, so any
   app restart/crash between session-end and tagging silently lost that
   session's count entirely. Don't revert to recording only on tag selection.

10. **The app refuses to launch a second instance** (`AppDelegate.applicationWillFinishLaunching`
    in `FocusTimeApp.swift`, checked via `NSRunningApplication.runningApplications(withBundleIdentifier:)`).
    This matters because macOS's own launch deduplication is path-based, not
    bundle-ID-based — a dev build at `/tmp/...` and the installed copy at
    `/Applications/FocusTime.app` share a bundle ID but are "different apps" to
    `open`, so both could run at once. Since `SessionHistory` persists by
    serializing its *entire* in-memory dictionary to `UserDefaults` on every
    write (no locking, no merge), two live instances silently clobber each
    other's session history — whichever saves last wins outright. This was
    caught live: a dev-build test session's write got overwritten by a
    still-running `/Applications` instance from earlier testing. If you ever
    need multiple instances for testing again, explicitly `pkill` every other
    copy first — the guard will otherwise quit whichever one launches second.

## Known gaps not yet addressed

- No test target, no CI/CD, no notarization/signing pipeline (local "Sign to Run
  Locally" identity only — expect a Gatekeeper prompt if the app is ever re-copied
  from somewhere that gets it quarantined).
- `SessionHistory` calls `NotionService.shared` directly (`syncToNotion`) — no
  sync-target abstraction. Fine for a single destination; revisit if a second
  sync target is ever added.
- Force-unwraps on `Calendar.date(byAdding:)` in `HeatmapView.swift` and
  `SessionHistory.swift` (streak calculation) — theoretically crashable on
  DST edge cases, not yet guarded.
- `TerminalCommandCenter`'s polling bridge (0.5s `UserDefaults` polling +
  deprecated `synchronize()`) works but is a hand-rolled IPC; fine for personal
  use, first thing to replace if this needs to be more robust.
- iOS port has been discussed but not started — would need a new target, an
  iOS-appropriate Focus mechanism (`AppIntents`/Focus Filters instead of
  `shortcuts run`), and no Carbon hotkey/CLI bridge equivalent exists there.
