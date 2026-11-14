# Deviations from upstream

This repository repackages pstack. It does not rewrite it. Every skill body ships as the port wrote it, and every difference between this repository and upstream is packaging. This file lists each difference, the reason, and a command that verifies it. Re-run the commands after any upstream pull or `sync.sh` change; they are the contract that the repackaging stays packaging-only.

Upstream sources, pinned at packaging time:

| Work | Pin | Role |
|---|---|---|
| Lauren Tan, `cursor/plugins` folder `pstack` | `24621db`, plugin v0.15.36 | Origin of all skill content |
| Michael Denyer, `pstack-claude` port | `a12b047`, v0.9.138 | Build source: build-time Cursor-to-Claude translation; this repo consumes its `plugins/pstack` tree |
| This repository | `sync.sh` output, port version stamped in every manifest | Packaging for Zcode, Claude Code, claude.ai/Cowork, Codex, Hermes |

The live pin in each manifest is authoritative: `pstack/.zcode-plugin/plugin.json`, `pstack-cc/.claude-plugin/plugin.json`, `pstack-cc/.codex-plugin/plugin.json`, and both root marketplace manifests embed the port version and short SHA in their descriptions.

## What ships byte-identical

Verified 2026-11-14 against the port clone at pin `a12b047`:

| Content | Check | Result |
|---|---|---|
| 13 shared registered skills (unslop, tdd, arena, swarm, interrogate, sharpen, technical-writing, no-comments, babysit, architect, blast-radius, show-me-your-work, poteto-mode in `pstack-cc/`) | `diff -r <port>/plugins/pstack/skills/<name> <target>/skills/<name>` | 0 diff lines for every skill in `pstack-cc/` |
| Zcode `pstack/` registered skills | same command | byte-identical except `poteto-mode`, which differs by exactly the 12 generated Zcode adaptation lines (deviation 5) |
| `agents/poteto-agent.md`, `agents/comment-sicko.md` | `cmp` | identical in both plugin trees |
| All 23 playbooks | `diff -r` on `poteto-mode/playbooks/` | identical |
| 24 principle leaves, both plugin trees and Hermes | per-file diff | differ only by the removed `user-invocable: false` line (deviation 3) |
| `LICENSE`, `NOTICE-skills.md` | `cmp` | carried unchanged; NOTICE names all three upstream sources |

## Deviations

1. **Two-tier skill exposure.** The port registers all 67 skills (43 public + 24 `principle-*`) as flat skills. This repo registers a small tier as real skills and nests everything else under `pstack*/skills/poteto-mode/references/` (principles as `principles/<name>.md`, other skills as `skills/<name>/SKILL.md`). Registered tier: 15 for Zcode (13 port skills + generated `pstack-zcode`, `pstack-guide`), 15 for `pstack-cc/` (13 port skills + `setup-pstack` + generated `pstack-guide`). Reason: a flat install costs about 3,300 standing tokens per session in the skill index; the two-tier build measured ~993 always-on tokens for 15 skills plus 2 agents on Claude Code. Verify: count `skills/*` dirs versus `references/` entries; the `pstack-guide` skill lists both tiers.

2. **Excluded skills.** Nine port skills are not shipped: `deslop`, `fix-ci`, `fix-merge-conflicts`, `get-pr-comments`, `make-pr-easy-to-review`, `what-did-i-get-done` (cursor-team-kit extras, a separate upstream pack) and `thermos`, `thermo-nuclear-review`, `thermo-nuclear-code-quality-review` (thermos review pack), plus the two thermos subagent definitions they are the only consumers of. Verify: `test -d <port>/plugins/pstack/skills/thermos && test ! -d pstack-cc/skills/thermos`.

3. **Frontmatter normalization.** The `user-invocable: false` line (a Claude Code field the port sets on principle leaves) is stripped from every shipped SKILL.md. Operator decision, 2026-11-13. The field stays maintained upstream; a re-run of `sync.sh` re-strips it. Verify: `grep -rl '^user-invocable:' pstack*/skills hermes --include=SKILL.md | wc -l` returns 0.

4. **Generated files with no upstream counterpart.** `pstack-guide` skill (two variants: Zcode and Claude/Codex), root `SKILL-GUIDE.md`, `pstack-zcode` skill, `poteto-mode/references/zcode-tools.md`, the Zcode adaptation footer on the Zcode `poteto-mode` copy, `hermes/pstack-mode/` in full, and all four marketplace/plugin manifests. All are outputs of `sync.sh`; none are hand-edited. Reason: per-harness adaptation and the tier index. Verify: the header comment in each generated file says so.

5. **Zcode adaptation content.** The Zcode `poteto-mode` copy carries an appended "Zcode adaptation" section and a `zcode-tools.md` mapping that state plainly: tool names map one to one, every model role inherits the session model, review panels are single-model on Zcode and are declared as such. Reason: Zcode cannot select a model per subagent, and the operator rule is to declare single-model panels rather than fake diversity. The `pstack-cc/` tree keeps the port text unchanged because Claude Code and Codex select real per-subagent models. Verify: `diff -r <port>/plugins/pstack/skills/poteto-mode pstack/skills/poteto-mode` shows only the appended section.

6. **Hooks not shipped.** The port ships SessionStart hook files (`hooks/hooks.json`, `hooks/codex-hooks.json`, `hooks/copilot-hooks.json`, `session-start.sh` and helpers) that print routing context each session. No hooks ship here. Routing comes from instruction-file lines that the operator adds outside this repository (`~/.zcode/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`). Reason: zero script surface to maintain; the hook mechanism also depends on `/hooks` trust in Codex. Verify: `find pstack pstack-cc -name hooks -o -name '*.sh'` returns nothing.

7. **`models.json` not shipped.** The port carries `plugins/pstack/models.json` as the build-time source of role defaults. Nothing reads it at runtime; the defaults are stamped into the skill text (`setup-pstack` writes the operator's role sheet). Shipping it would add a dead file. Verify: `grep -rn "models.json" pstack-cc/skills/setup-pstack/SKILL.md` shows only the provenance comment.

8. **Manifest authorship and fields.** All four manifests name Dan Tembe as author and this repository as homepage/repository. The Claude manifest keeps `displayName`; the Codex manifest does not (top-level `displayName` is not part of the proven port Codex format; `interface.displayName` covers it; removed after independent review). No icon, logo, or brandColor fields: no asset is shipped. Marketplace names are `pstack-local` (Zcode) and `custom-pstack` (Claude and Codex); versions track the port `VERSION`.

9. **Hermes packaging is new.** The port has no Hermes target. This repo ships one router skill, `hermes/pstack-mode/`, instead of 58 flat skills, because Hermes has no slash commands, triggers skills by description match, and a flat install would bloat its skill index. Its references copy playbooks and principles verbatim. The two `references/agents/*-brief.md` files are the one place prose is re-expressed: the port's Claude-Code agent definitions are rewritten as `delegate_task` brief templates with the same rules and voice. Reason: Hermes delegates receive a task brief, not a subagent definition. Verify: `diff -r <port>/plugins/pstack/skills/poteto-mode/playbooks hermes/pstack-mode/references/playbooks` is empty; `wc -c hermes/pstack-mode/SKILL.md` is under 8000 (a build guard fails the script above that).

## Not a deviation

- `setup-pstack` behavior, skill descriptions, playbook steps, principle text, reply rules, and the skip policy are the port's own text.
- The port's `user-invocable` field handling, `hooks/` layout, and `models.json` remain maintained upstream; this repo re-applies its deltas on every `sync.sh` run rather than forking the content.
- The operator's instruction-file routing lines live outside this repository by design; the repo stays machine-independent.
