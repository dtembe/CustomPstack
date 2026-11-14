---
name: pstack-guide
description: Index of the pstack skills available in this plugin and when to invoke each. Use when unsure which pstack skill applies, when asked what pstack provides, or to find a pstack skill or principle by name.
---

# pstack skill guide (Claude Code / Codex)

pstack is Lauren Tan's rigorous engineering stack (MIT), shipped for Claude Code and Codex via the michael-denyer port. Two tiers: registered skills below are always visible to the model (invoke with /name or describe the need); reference leaves load only when read from disk.

## Routing rules

1. Non-trivial coding task: nothing to invoke by hand. poteto-mode owns the playbook and todo list and pulls principles as needed. For automatic routing on every non-trivial task, add the router line to your instruction file (CLAUDE.md, AGENTS.md, or the Codex equivalent): "For non-trivial coding tasks, load and follow the poteto-mode skill; skip Cursor-only steps with a one-line note."
2. Know the specific skill: invoke /name from the registered table.
3. Not sure: read the tables below; the descriptions are the port's own. Reference leaves are listed at the bottom with their on-disk paths.

## Registered skills

| Skill | Invoke | First line of its description |
|---|---|---|
| pstack-guide | /pstack-guide | Index of the pstack skills available in this plugin and when to invoke each. Use when unsure which pstack skill applies, when asked what pstack provides, or to  |
| poteto-mode | /poteto-mode | poteto's agent style for concise, detailed responses, deliberate subagents, unslopped prose, simple code, and verified work. Use for poteto, /poteto-mode, or re |
| unslop | /unslop | Cut AI tells from any writing. |
| tdd | /tdd | Use only when the user explicitly asks for TDD, a failing test, or a regression test, OR when the bug has an obvious cheap local test target. Skip when the test |
| arena | /arena | Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for /arena, 'arena this', 'throw it in the arena |
| swarm | /swarm | Fan out N parallel workers, drain them, and return one report. Use for /swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration. |
| interrogate | /interrogate | Use for "interrogate", "adversarial review", "multi-model review", "challenge this", "stress test this code", "find blind spots", or "tear this apa |
| sharpen | /sharpen | Make a task deeper, not bigger, then rewrite the prompt. Use for /sharpen. |
| technical-writing | /technical-writing | Layered technical-writing standard: Diátaxis structure, Google developer style sentences, STE instruction rules, Global English syntax. Use for /technical-writi |
| no-comments | /no-comments | Spawn the comment-sicko subagent, fix accepted findings, and offer encodings for claimed constraints. |
| babysit | /babysit | Watch an open PR — fix failing CI, handle the straightforward review comments, and drive it to a mergeable state. Claude Code analog of Cursor's built-in /babys |
| architect | /architect | Sketch types, signatures, and module structure before code, then stay in the loop while implementation fills in. Use for /architect, 'architect this', 'design t |
| blast-radius | /blast-radius | Find what a change could break somewhere else before it ships, beyond the diff, and prove the one fact it's safe because of by running real code instead of writ |
| show-me-your-work | /show-me-your-work | Keep a reviewable decision trail for long-running or unattended work: a TSV log with one row per decision (what, why, evidence, result). Local by default; commi |
| setup-pstack | /setup-pstack | Configure which models pstack uses per role. Detects available models and writes the current runtime's override sheet. Use for /setup-pstack, "configure pstack  |

## Reference leaves (read on demand, no auto-trigger)

Principles live at `poteto-mode/references/principles/<name>.md`; other leaves at `poteto-mode/references/skills/<name>/SKILL.md` (paths relative to the poteto-mode skill directory).

### Principles
- principle-attack-the-premise
- principle-boundary-discipline
- principle-build-the-lever
- principle-encode-lessons-in-structure
- principle-exhaust-the-design-space
- principle-experience-first
- principle-explain-the-number
- principle-fix-root-causes
- principle-foundational-thinking
- principle-guard-the-context-window
- principle-laziness-protocol
- principle-make-operations-idempotent
- principle-migrate-callers-then-delete-legacy-apis
- principle-minimize-reader-load
- principle-model-the-domain
- principle-never-block-on-the-human
- principle-outcome-oriented-execution
- principle-prove-it-works
- principle-redesign-from-first-principles
- principle-separate-before-serializing-shared-state
- principle-sequence-verifiable-units
- principle-subtract-before-you-add
- principle-test-behavior-not-implementation
- principle-type-system-discipline

### Other skills
- automate-me
- benchmark-checklist
- bro
- correct
- create-formal-verification-skill
- create-verification-skill
- figure-it-out
- how
- in-your-own-words
- ketchup-video
- ketchup
- maintain-formal-verification-skill
- maintain-verification-skill
- poteto-help
- recall
- reflect
- statechart
- teach
- typescript-best-practices
- why

## Not in this build

Cursor-team-kit extras (deslop, fix-ci, fix-merge-conflicts, get-pr-comments, make-pr-easy-to-review, what-did-i-get-done) and the thermos review pack (thermos, thermo-nuclear-review, thermo-nuclear-code-quality-review) are excluded by this repository's packaging decision (see the README, "What this packaging changes").

Source: port version 0.9.138, pin a12b047. Regenerated by sync.sh in this repository; edit that script's tier lists and re-run to promote or demote skills.
