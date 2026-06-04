#!/usr/bin/env python3
"""
verify-relay-logic.py — reproducible, hardware-free verification of the two
correctness-critical algorithms in the ShiftBlast relay ⇆ iOS pipeline.

These are faithful 1:1 ports of the Swift logic so the behaviour can be proven
in CI without a Mac, an iPhone, or iCloud:

  1. SentinelChangeTracker  (iOS AgentSignalWatcher) — must fire on real signals
     regardless of Mac↔iPhone clock skew, baseline each source, and dedupe.

  2. SessionFileWatcher turn state machine (macOS relay) — must detect turn ends
     for both event-based agents (Codex) and silence-only agents, including
     back-to-back turns, without emitting spurious signals.

Run:  python3 scripts/verify-relay-logic.py   (exit 0 = all green)

If you change the Swift logic, mirror it here so this stays a real guardrail.
"""

import sys

SILENCE = 15.0
LATE_WINDOW = 20.0

# --------------------------------------------------------------------------
# 1. SentinelChangeTracker  (mirror of ShiftBlast/AgentSignalWatcher.swift)
# --------------------------------------------------------------------------

class SentinelChangeTracker:
    def __init__(self):
        self.last_seen = {}
        self.baselined = set()
        self.last_fired = None

    def observe(self, date, source):
        is_first = source not in self.baselined
        self.baselined.add(source)
        try:
            if is_first:
                return False
            if date is None:
                return False
            if date == self.last_seen.get(source):
                return False
            if self.last_fired is not None and date <= self.last_fired:
                return False
            self.last_fired = date
            return True
        finally:
            if date is not None:
                self.last_seen[source] = date

POLL, META = "polling", "metadata"


def tracker_cases():
    t0 = 1000
    c = []

    def t(name, fn):
        c.append((name, fn))

    def case_baseline():
        tk = SentinelChangeTracker()
        assert tk.observe(t0, POLL) is False
        assert tk.observe(t0, META) is False
    t("tracker: first observation per source is baseline", case_baseline)

    def case_fires_once():
        tk = SentinelChangeTracker()
        tk.observe(t0, POLL)
        assert tk.observe(t0 + 1, POLL) is True
        assert tk.observe(t0 + 1, POLL) is False
    t("tracker: new change fires once", case_fires_once)

    def case_appears():
        tk = SentinelChangeTracker()
        assert tk.observe(None, POLL) is False
        assert tk.observe(None, META) is False
        assert tk.observe(t0, POLL) is True
    t("tracker: file appearing after launch fires", case_appears)

    def case_preexisting():
        tk = SentinelChangeTracker()
        assert tk.observe(t0, POLL) is False
        assert tk.observe(t0, META) is False
        assert tk.observe(t0, POLL) is False
        assert tk.observe(t0, META) is False
    t("tracker: pre-existing sentinel never fires", case_preexisting)

    def case_skew():
        tk = SentinelChangeTracker()
        ancient = 0  # Mac clock far behind the phone's "now"
        assert tk.observe(ancient, POLL) is False
        assert tk.observe(ancient + 1, POLL) is True
    t("tracker: clock skew does not swallow signals", case_skew)

    def case_dual_source():
        tk = SentinelChangeTracker()
        tk.observe(t0, POLL); tk.observe(t0, META)
        assert tk.observe(t0 + 5, META) is True
        assert tk.observe(t0 + 3, POLL) is False
    t("tracker: two sources, one write, no double-fire on older date", case_dual_source)

    def case_out_of_order():
        tk = SentinelChangeTracker()
        tk.observe(t0, META)
        assert tk.observe(t0 + 10, META) is True
        assert tk.observe(t0 + 4, META) is False
        assert tk.observe(t0 + 11, META) is True
    t("tracker: out-of-order metadata update ignored", case_out_of_order)

    def case_nil_after_baseline():
        tk = SentinelChangeTracker()
        tk.observe(t0, POLL)
        assert tk.observe(None, POLL) is False
    t("tracker: nil after baseline does not fire", case_nil_after_baseline)

    return c


# --------------------------------------------------------------------------
# 2. Turn state machine  (mirror of ShiftBlastRelay/SessionFileWatcher.swift)
# --------------------------------------------------------------------------

class TurnMachine:
    def __init__(self):
        self.is_turn_active = False
        self.debounce_fire_at = None
        self.last_finished_at = None
        self.last_finish_was_event = False
        self.signals = []

    def _ignoring_late(self, now):
        return (self.last_finish_was_event
                and self.last_finished_at is not None
                and (now - self.last_finished_at) < LATE_WINDOW)

    def finish_event(self, now):           # Codex task_complete / turn_aborted
        self.debounce_fire_at = None
        self.is_turn_active = False
        self.last_finished_at = now
        self.last_finish_was_event = True
        self.signals.append(round(now, 3))

    def activity(self, now):               # any tracked write
        if not self.is_turn_active and not self._ignoring_late(now):
            self.is_turn_active = True
        self.debounce_fire_at = now + SILENCE

    def tick(self, now):                   # silence timer fires
        if self.debounce_fire_at is not None and now >= self.debounce_fire_at:
            self.debounce_fire_at = None
            if self._ignoring_late(now):
                self.is_turn_active = False
                return
            self.is_turn_active = False
            self.last_finished_at = now
            self.last_finish_was_event = False
            self.signals.append(round(now, 3))


def run_machine(events):
    m = TurnMachine()
    ev = sorted(events)
    end = ev[-1][0] + SILENCE + LATE_WINDOW + 5
    i, t = 0, 0.0
    while t <= end:
        while i < len(ev) and abs(ev[i][0] - t) < 1e-9:
            time_, kind = ev[i]
            (m.activity if kind == "activity" else m.finish_event)(time_)
            i += 1
        m.tick(t)
        t = round(t + 0.5, 3)
    return m.signals


def machine_cases():
    c = []

    def t(name, fn):
        c.append((name, fn))

    t("machine: codex single turn -> one signal", lambda: _eq(
        run_machine([(2, "activity"), (3, "activity"), (4, "finish")]), [4]))
    t("machine: codex trailing writes -> no spurious", lambda: _eq(
        run_machine([(2, "activity"), (4, "finish"), (4.1, "activity"), (4.3, "activity")]), [4]))
    t("machine: codex back-to-back -> two signals", lambda: _eq(
        run_machine([(2, "activity"), (4, "finish"), (8, "activity"), (9, "activity"), (10, "finish")]), [4, 10]))
    t("machine: silence-only single turn -> one signal", lambda: _eq(
        run_machine([(2, "activity"), (3, "activity")]), [18.0]))
    t("machine: silence-only back-to-back within 20s -> two signals", lambda: _len(
        run_machine([(2, "activity"), (3, "activity"), (19, "activity"), (20, "activity")]), 2))
    t("machine: silence-only well-separated -> two signals", lambda: _len(
        run_machine([(2, "activity"), (50, "activity")]), 2))
    return c


def _eq(got, want):
    assert got == want, f"expected {want}, got {got}"


def _len(got, n):
    assert len(got) == n, f"expected {n} signals, got {got}"


# --------------------------------------------------------------------------

def main():
    cases = tracker_cases() + machine_cases()
    failed = 0
    for name, fn in cases:
        try:
            fn()
            print(f"PASS  {name}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL  {name}: {e}")
    print(f"\n{len(cases) - failed}/{len(cases)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
