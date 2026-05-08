---
description: Send a test notification to ShiftBlast
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/notify-shiftblast.sh:*)
---

# ShiftBlast Test

Run the ShiftBlast notification script once:

!`${CLAUDE_PLUGIN_ROOT}/scripts/notify-shiftblast.sh manual-test`

Tell the user whether the command completed. If ShiftBlast is open on iPhone and paired, it should show AGENTE PRONTO.
