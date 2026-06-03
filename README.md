# ShiftBlast 🎮⚡

**A puzzle game that pings you the moment your AI agent finishes.**

You kick off a long Claude Code task, then start procrastinating. ShiftBlast is
the game you procrastinate *in* — and the instant Claude Code finishes (via a
`Stop` / `SubagentStop` hook), the game pauses and taps you on the shoulder:

> **Agent ready.** Your work is waiting. → *Back to work* / *One more move*

So you stay in flow instead of context-switching to babysit a terminal.

## How it works

```
Claude Code finishes ─▶ plugin hook ─▶ iCloud sentinel ─▶ iPhone game pauses ─▶ you get back to work
```

- A tiny **Claude Code plugin** (`shiftblast-alert`) fires on Stop/SubagentStop.
- It writes a sentinel file into the ShiftBlast iCloud container.
- The **iOS game** watches that file and pauses the moment your agent is done.

## Install the Claude Code plugin

From any machine with Claude Code:

```text
/plugin marketplace add davidecapurr/giochino
/plugin install shiftblast-alert@shiftblast
```

Restart Claude Code, then test the link:

```text
/shiftblast-test
```

Pair it with the **ShiftBlast iPhone app** (the app shows the pairing step), and
you're set.

## Why it's built this way

The agent-alert is the differentiated, paid feature — the rest is a genuinely
fun, fast block-slide puzzle (Game Center leaderboards, combos, overdrive). The
free game is ad-supported; **Premium** unlocks the AI-agent connection and
removes ads.

## Repo layout

| Path | What |
|------|------|
| `ShiftBlast/` | iOS app (SwiftUI) |
| `ShiftBlastRelay/` | macOS relay helper (writes the sentinel) |
| `claude-marketplace/` | the `shiftblast-alert` Claude Code plugin |
| `docs/` | landing page + privacy/terms (GitHub Pages) + strategy notes |

See [`docs/MONETIZATION.md`](docs/MONETIZATION.md) and
[`docs/GROWTH.md`](docs/GROWTH.md) for how the project plans to earn and grow.
