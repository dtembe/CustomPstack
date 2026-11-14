# pstack-mode Hermes smoke test

Run the prompt below in a fresh Hermes session, then record the evidence in `builds/REPORT.md` (seed folder, one row per surface). Fixture: `builds/zcode/smoke/stats.py`, whose `median()` returns the lower middle value for even-length lists. Baseline repro (measured 2026-11-13):

```
median([1, 3, 2])      -> 2 (expect 2)
median([1, 2, 3, 4])   -> 3 (expect 2.5)
median([10])           -> 10 (expect 10)
median([5, 1, 9, 7])   -> 7 (expect 6.0)
```

## Prompt

```
Use pstack-mode to fix the bug in /Users/dtembe/Documents/Claude-Files/pstack/builds/zcode/smoke/stats.py: median() is wrong for even-length lists. Repro first, then fix and verify by re-running the script.
```

## Acceptance (dev plan H6, all observed not claimed)

1. `todo_list` opened with playbook steps verbatim.
2. At least one `delegate_task` child spawned with the poteto-agent brief pattern: goal plus full context, absolute file paths. Template: `references/agents/poteto-agent-brief.md` inside the installed skill.
3. Final reply: repro evidence (command plus output), the fix, a re-run of the original repro, and claims labeled measured/inferred/guess.
4. Zero Cursor-only steps executed (no Automations, no Bugbot); any skipped step appears as one `Skipped: <step>. <reason>.` line.

## Install facts

Skill: `~/.hermes/skills/software-development/pstack-mode`, a symlink to `hermes/pstack-mode/` in this repository. Updates are `git pull` plus `./sync.sh`; no reinstall step. Discovery check: `hermes skills list` shows `pstack-mode | software-development | local | enabled`.
