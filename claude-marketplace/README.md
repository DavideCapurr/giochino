# ShiftBlast Claude Code Plugin

`shiftblast-alert` notifies the ShiftBlast iPhone game the moment Claude Code
finishes a response, so you stop procrastinating and get back to work.

## Install (public — anyone can run this)

```text
/plugin marketplace add davidecapurr/giochino
/plugin install shiftblast-alert@shiftblast
```

Restart Claude Code after installing.

## Install (local checkout)

```text
/plugin marketplace add ./claude-marketplace
/plugin install shiftblast-alert@shiftblast-local
```

Test:

```text
/shiftblast-test
```

The plugin uses the Claude Code `Stop` and `SubagentStop` hooks. It first calls `~/.shiftblast/bin/shiftblast done` if the Relay helper is installed. If not, it writes directly to the ShiftBlast iCloud sentinel using the pairing file created by the iPhone app.
