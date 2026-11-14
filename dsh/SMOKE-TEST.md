# pstack-dsh bundle smoke test

Run the prompt below in a fresh headless dsh session, then record the evidence in `builds/REPORT.md` (seed folder, one row per surface). The exact command (the headless profile runs one fresh persisted session, prints the final answer, and exits):

```
dsh --profile headless "Use the poteto-mode skill to fix the bug in /Users/dtembe/Documents/Claude-Files/pstack/builds/zcode/smoke/stats.py: median() is wrong for even-length lists. Repro first, then fix and verify by re-running the script."
```

Fixture: `builds/zcode/smoke/stats.py`, whose `median()` returns the lower middle value for even-length lists. Baseline repro (from the Hermes smoke test, same fixture, measured 2026-11-13):

```
median([1, 3, 2])      -> 2 (expect 2)
median([1, 2, 3, 4])   -> 3 (expect 2.5)
median([10])           -> 10 (expect 10)
median([5, 1, 9, 7])   -> 7 (expect 6.0)
```

## Acceptance (all observed, not claimed)

1. Layer check: `dsh --profile headless --dump-config` shows the custom-pstack-dsh layer, and the session catalog lists the bundle's skills (poteto-mode among them).
2. poteto-mode drives the run: a todo list (`todo_write`) opened with playbook steps verbatim, and at least one `subagent` or `subagent_fork` child carrying the brief pattern: goal plus full context, absolute file paths.
3. Final reply: repro evidence (command plus output), the fix, a re-run of the original repro, and claims labeled measured/inferred/guess.
4. Zero Cursor-only steps executed (no Automations, no Bugbot); any skipped step appears as one `Skipped: <step>. <reason>.` line.

## Install facts

Bundle: `dsh plugin --profile <name> add github:dtembe/CustomPstack#dsh-<version>` or a local path add. Updates are `git pull` plus `./sync.sh`, then the same `dsh plugin add` again. The fixture is restored to its buggy state afterward, so the next run reproduces.
