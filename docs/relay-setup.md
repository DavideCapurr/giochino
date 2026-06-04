# ShiftBlast Relay ⇆ iOS app

How the macOS menu-bar **ShiftBlast Relay** talks to the **ShiftBlast** iOS game,
and how to verify the link works end to end.

## How it works

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

1. The relay watches whichever agent transcript folder you authorize
   (`~/.codex/sessions`, `~/.claude/projects`, `~/.aider`). It detects when the
   agent **starts** and **finishes** a turn by parsing the session JSONL, with a
   15-second silence window as a fallback.
2. On each turn end it touches a single sentinel file, `agent-stop.flag`, in the
   app's shared iCloud Documents container.
3. iCloud Drive syncs that file to the phone.
4. The iOS app watches the sentinel's content-change date and pauses the game so
   you notice your agent is waiting for you.

The producer (`SentinelWriter`) and consumer (`AgentSignalWatcher` /
`AgentBridgeICloud`) agree on two constants only:

| Constant            | Value                          |
| ------------------- | ------------------------------ |
| iCloud container    | `iCloud.com.davide.shiftblast` |
| Sentinel file name  | `agent-stop.flag`              |

These are asserted by `AgentBridgeTests`.

The two correctness-critical algorithms — the iOS sentinel tracker and the relay
turn state machine — also have a hardware-free, reproducible guardrail:
`python3 scripts/verify-relay-logic.py` (faithful 1:1 ports, 14 cases). Run it in
CI or after editing the Swift logic.

## Why the watcher ignores wall-clock time

The sentinel is written by a *different machine* than the one reading it, so its
modification / content-change date is on the Mac's clock, not the phone's. An
earlier version dropped any change whose date was `<= appLaunchTime`; if the Mac
clock trailed the phone's by a few seconds, **every** real signal looked stale
and the relay appeared dead.

`SentinelChangeTracker` fixes this: it never compares to wall time. The first
observation from each source (metadata query + polling) is only a baseline, and
afterwards any unseen, newer change date fires exactly once. `AgentBridgeTests`
covers the clock-skew, file-appears-after-launch, dedupe and out-of-order cases.

## Verifying end to end

Requirements that can only be checked on real hardware:

1. **Same iCloud account** signed in on the Mac and the iPhone, with **iCloud
   Drive enabled** on both.
2. The iCloud container `iCloud.com.davide.shiftblast` must be provisioned for
   both the app and the relay bundle IDs in the Apple Developer portal (it is in
   both targets' entitlements).
3. In the iOS app, the AI agent bridge is **Premium-gated** — Settings shows
   `iCloud bridge connected` (lime) when the container is reachable. The
   `GameViewModel` only starts `AgentSignalWatcher` while `isAgentEnabled`
   (i.e. premium) is true.
4. In the relay menu, authorize `~/.codex/sessions` (or your agent's folder).
   The status line should read `monitor attivo su N cartelle`.

### Two ways to verify without running an agent

Detection (parsing the agent transcript) and transport (iCloud → iOS) are
independent. Test transport in isolation first — if it works, any remaining
issue is detection-only.

- **From the relay menu:** click **Invia segnale di test**. It writes a sentinel
  immediately, bypassing the throttle. The menu shows a green/orange dot:
  `iCloud collegato` means the real ubiquity container is reachable;
  `iCloud non pronto` means the write can't sync (sign in / enable iCloud Drive).
- **Without the relay at all:** run `scripts/send-test-sentinel.sh` on the Mac.
  It writes the same payload straight into the shared iCloud container, so you
  can confirm the iOS side reacts even if the relay isn't installed.
- **If the link fails:** run `scripts/diagnose-relay.sh` (add `--probe` to also
  write-test the container). It checks iCloud Drive, the shared container, the
  sentinel, and the relay process, and pinpoints the first blocking problem.

With the iOS app (premium build) open in the foreground, either method should
pause the game within a few seconds and log `📡 sentinella rilevata`.

### Full smoke test

1. Launch the relay, authorize the Codex sessions folder. Confirm the menu shows
   `iCloud collegato`.
2. Open the iOS app (premium build) and start a game.
3. Run a Codex turn on the Mac. When it finishes, the relay logs
   `📡 SENTINELLA scritta`; within a few seconds the phone logs
   `📡 sentinella rilevata` and the game pauses.

Console filters: subsystem `com.davide.shiftblast.relay` (Mac) and
`com.davide.shiftblast` (iOS).
