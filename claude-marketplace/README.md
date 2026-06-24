# ShiftBlast Claude Code Plugin

`shiftblast-alert` notifies the ShiftBlast iPhone game directly through iCloud
the moment Claude Code finishes or needs your attention, so you stop
procrastinating and get back to work. No ShiftBlast Relay install is required.

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

The plugin uses the Claude Code `Stop`, `SubagentStop`, `Notification`, and
`StopFailure` hooks. Each hook writes `agent-stop.flag` directly into the
ShiftBlast iCloud container:

```text
~/Library/Mobile Documents/iCloud~com~davide~shiftblast/Documents/agent-stop.flag
```

Requirements: iCloud Drive enabled on the Mac, the same iCloud account on the
iPhone, and ShiftBlast Premium enabled in the iPhone app.
