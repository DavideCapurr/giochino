# ShiftBlast agent bridge ⇆ iOS app

How Claude Code talks directly to the **ShiftBlast** iOS game through iCloud,
and how the optional legacy **ShiftBlast Relay** fits in for agents without
native hooks.

> **Why a phone can't just read the agent's notification.** iOS sandboxing forbids
> any app from reading another app's notifications, so ShiftBlast can never
> "intercept" a Claude Code / Codex notification directly. The signal must be
> delivered to the ShiftBlast app itself. The only options are a shared iCloud
> file (used here, no backend) or a real push via APNs (needs a server). The
> iCloud sentinel is the simplest native channel that works without infrastructure.

## Simplest setup: the Claude Code plugin (recommended)

Users should not need to install the standalone relay app. The Claude Code
plugin is the trigger: its hooks fire when the agent finishes, when a subagent
finishes, when Claude needs attention, or when a turn fails.

```
Claude Code finishes / needs attention
        │  Stop / SubagentStop / Notification / StopFailure hook
        ▼
shiftblast-alert plugin ──writes──▶ agent-stop.flag (iCloud) ──sync──▶ ShiftBlast (iOS)
                                                                          → game pauses
```

This removes all the moving parts of the menubar relay (FSEvents, security-scoped
bookmarks, JSONL parsing, file-descriptor limits) and reuses the already-tested
iCloud → iOS half (`AgentSignalWatcher`).

**Install once on the Mac**:

```text
/plugin marketplace add davidecapurr/giochino
/plugin install shiftblast-alert@shiftblast
```

Restart Claude Code, then run `/shiftblast-test`. The plugin script always exits
0 (a best-effort phone pause must never block Claude), writes atomically, and
self-heals an evicted iCloud sentinel. With the same iCloud account, iCloud
Drive enabled, and Premium active in the iPhone app, the phone should pause
within a few seconds.

The standalone **ShiftBlast Relay** app documented in the rest of this file
remains a valid alternative — e.g. if you want to bridge Codex/Aider, or another
agent that doesn't expose a Stop hook.

## How it works

Recommended Claude Code path:

```
Claude Code hook                 iCloud Drive                 ShiftBlast (iOS)
        │                      (Documents folder of            │
        ▼                       iCloud.com.davide.shiftblast)  │
notify-shiftblast.sh ──writes──▶ agent-stop.flag ──sync──────▶ AgentSignalWatcher
                                                                  │
                                                            handleAgentReadySignal()
                                                            → game pauses
```

1. The plugin registers `Stop`, `SubagentStop`, `Notification`, and `StopFailure`
   hooks.
2. Each hook runs `notify-shiftblast.sh`, which writes `agent-stop.flag` directly
   into the app's shared iCloud Documents container.
3. iCloud Drive syncs that file to the phone.
4. The iOS app watches the sentinel's content-change date and pauses the game so
   you notice your agent is waiting for you.

Optional legacy relay path:

```
~/.codex/sessions/**.jsonl        iCloud Drive                 ShiftBlast (iOS)
        │                       (Documents folder of            │
   FSEvents + 1s poll            iCloud.com.davide.shiftblast)   │
        │                              │                         │
   SessionFileWatcher  ──writes──▶  agent-stop.flag  ──sync──▶  AgentSignalWatcher
   (parses task_started /                                        (NSMetadataQuery +
    task_complete events,                                         0.75s poll)
    15s silence fallback)                                              │
        │                                                        handleAgentReadySignal()
   RelayCoordinator.signal() ──▶ SentinelWriter.touch()          → game pauses
```

The relay watches whichever agent transcript folder you authorize
(`~/.codex/sessions`, `~/.claude/projects`, `~/.aider`). It detects turn start
and finish by parsing session JSONL, with a 15-second silence window fallback,
then writes the same `agent-stop.flag` sentinel. Keep this for agents that do
not expose a first-class hook.

The producers (`notify-shiftblast.sh` and `SentinelWriter`) and consumer
(`AgentSignalWatcher` / `AgentBridgeICloud`) agree on two constants only:

| Constant            | Value                          |
| ------------------- | ------------------------------ |
| iCloud container    | `iCloud.com.davide.shiftblast` |
| Sentinel file name  | `agent-stop.flag`              |

These are asserted by `AgentBridgeTests`.

The two correctness-critical algorithms — the iOS sentinel tracker and the
legacy relay turn state machine — also have a hardware-free, reproducible
guardrail:
`python3 scripts/verify-relay-logic.py` (faithful 1:1 ports, 14 cases). Run it in
CI or after editing the Swift logic.

## Why the watcher ignores wall-clock time

The sentinel is written by a *different machine* than the one reading it, so its
modification / content-change date is on the Mac's clock, not the phone's. An
earlier version dropped any change whose date was `<= appLaunchTime`; if the Mac
clock trailed the phone's by a few seconds, **every** real signal looked stale
and the bridge appeared dead.

`SentinelChangeTracker` fixes this: it never compares to wall time. The first
observation from each source (metadata query + polling) is only a baseline, and
afterwards any unseen, newer change date fires exactly once. `AgentBridgeTests`
covers the clock-skew, file-appears-after-launch, dedupe and out-of-order cases.

## Verifying end to end

Requirements that can only be checked on real hardware:

1. **Same iCloud account** signed in on the Mac and the iPhone, with **iCloud
   Drive enabled** on both.
2. The iCloud container `iCloud.com.davide.shiftblast` must be provisioned for
   the iOS app in the Apple Developer portal.
3. In the iOS app, the AI agent bridge is **Premium-gated** — Settings shows
   `iCloud bridge connected` (lime) when the container is reachable. The
   `GameViewModel` only starts `AgentSignalWatcher` while `isAgentEnabled`
   (i.e. premium) is true.
4. Claude Code has the `shiftblast-alert` plugin installed and has been
   restarted after installation.

### Two ways to verify without running an agent

Hook detection and transport (iCloud → iOS) are independent. Test transport in
isolation first — if it works, any remaining issue is hook/plugin-only.

- **From Claude Code:** run `/shiftblast-test`. It invokes the installed plugin
  and writes the same sentinel real hooks use.
- **From a shell:** run `scripts/send-test-sentinel.sh` on the Mac.
  It writes the same payload straight into the shared iCloud container, so you
  can confirm the iOS side reacts even if Claude Code is not involved.
- **From the optional relay menu:** click **Invia segnale di test**. It writes a
  sentinel immediately, bypassing the throttle.
- **If the link fails:** run `scripts/diagnose-relay.sh` (add `--probe` to also
  write-test the container). It checks iCloud Drive, the shared container, the
  sentinel, and, if present, the optional relay process.

With the iOS app (premium build) open in the foreground, either method should
pause the game within a few seconds and log `📡 sentinella rilevata`.

### Full smoke test

1. Install `shiftblast-alert`, restart Claude Code, and run `/shiftblast-test`.
2. Open the iOS app (premium build) and start a game.
3. Finish a Claude Code turn, trigger a permission/idle notification, or hit a
   stop failure. The plugin writes the sentinel; within a few seconds the phone
   logs `📡 sentinella rilevata` and the game pauses.

Plugin logs: `~/Library/Logs/ShiftBlast/claude-plugin.log`. iOS Console filter:
subsystem `com.davide.shiftblast`.

## Security posture

Threat model and the defenses that back it:

- **No network surface.** Neither the plugin/relay nor the watcher opens a
  socket. The only channel is the iCloud sentinel file. There is nothing to
  attack remotely.
- **Account-scoped channel.** The sentinel lives in the user's
  `iCloud.com.davide.shiftblast` container and syncs through the same iCloud
  account as the iPhone app. The Claude Code plugin writes from the local user's
  Mac account into the corresponding iCloud Drive folder; the iOS app still
  reads only its entitled ubiquity container. This is not a remote API surface,
  but another local process running as the same Mac user could write the same
  file.
- **Untrusted transcript parsing is contained.** This applies only to the
  optional legacy relay. It parses agent JSONL with `JSONSerialization` and
  optional casts only; values drive a state machine via string comparisons and
  are never interpolated into a path, command, or query. Parse failures degrade
  to "activity". Reads are bounded (8 MB per pass, 1 MB partial line) so a
  corrupt/inflated file can't exhaust memory.
- **Least privilege file access.** This applies only to the optional legacy
  relay. It is sandboxed with **read-only** user-selected file access via
  security-scoped bookmarks, and `shouldTrack` resolves symlinks and refuses any
  file that escapes a granted root — so a symlink planted in a watched folder
  can't redirect reads outside the tree.
- **No payload trust on iOS.** The app reacts only to the sentinel's
  modification date; it never parses the payload, so the file's contents are not
  an input to any sink.

A focused security review of this branch found no exploitable vulnerabilities.
