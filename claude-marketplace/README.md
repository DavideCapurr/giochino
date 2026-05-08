# ShiftBlast Claude Code Plugin

This local marketplace installs `shiftblast-alert`, a Claude Code plugin that notifies ShiftBlast when Claude Code finishes a response.

Install from Claude Code:

```text
/plugin marketplace add ./claude-marketplace
/plugin install shiftblast-alert@shiftblast-local
```

Restart Claude Code after installing.

Test:

```text
/shiftblast-test
```

The plugin uses the Claude Code `Stop` and `SubagentStop` hooks. It first calls `~/.shiftblast/bin/shiftblast done` if the Relay helper is installed. If not, it writes directly to the ShiftBlast iCloud sentinel using the pairing file created by the iPhone app.
