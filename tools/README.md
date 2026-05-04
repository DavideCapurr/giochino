# Agent Watch

Run `tools/ai-watch` while Shift Blast is open in the iOS Simulator. It watches for Codex and Claude Code processes on the Mac and tells the app when they start and when all of them finish.

```sh
tools/ai-watch
```

The watcher sends deep links to the booted simulator with `xcrun simctl openurl`, so the app must be installed and running in the Simulator at least once.

Useful options:

```sh
tools/ai-watch --interval 1
tools/ai-watch --device booted
tools/ai-watch --status
tools/ai-watch --dry-run
```

`tools/agent-alert` is still available as a manual wrapper for one command when you only want a macOS notification:

```sh
tools/agent-alert xcodebuild -project ShiftBlast.xcodeproj -scheme ShiftBlast build
```

For a shorter terminal command, add this alias to your shell profile:

```sh
alias aa='/Users/davidecapurro/Documents/New project 3/tools/agent-alert'
```
