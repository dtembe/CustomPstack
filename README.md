# CustomPstack - pstack for Zcode

A Zcode plugin packaging of pstack, Lauren Tan's rigorous engineering skill stack for coding agents. This repository exists to run pstack natively in Zcode with a two-tier skill exposure that keeps session context small.

## Credits and provenance

This project only exists because of the work of others. In order of contribution:

| Work | Author | Source | License | Role in this repo |
|---|---|---|---|---|
| pstack (original) | Lauren Tan | https://github.com/cursor/plugins (folder `pstack`) | MIT | The original skill content and workflow design. All substantive skill text descends from this work. |
| pstack-claude (port) | Michael Denyer | https://github.com/michael-denyer/pstack-claude | MIT | Build-time translation of Cursor names to Claude Code names. The skill text shipped in `pstack/` is this port's content, version 0.9.138, source pin `a12b047`. |
| Zcode packaging | Dan Tembe | this repository | MIT | Zcode plugin manifest, two-tier skill exposure, frontmatter normalization, Zcode adaptation notes, and the `sync.sh` build script. |

Not affiliated with, endorsed by, or produced by Lauren Tan, Cursor, Michael Denyer, or Z.ai. All credit for the pstack methodology and skill content belongs to the original authors. This packaging is permitted by the MIT licenses of both upstream works, and the license notices travel with the content (`pstack/LICENSE`, `pstack/NOTICE-skills.md`, which records all three upstream sources).

## What this packaging changes vs the port

1. Two-tier exposure. Only 15 skills register as real Zcode skills (about 1,300 to 1,500 tokens of standing index per session). The other 45 ship as on-demand reference files under `pstack/skills/poteto-mode/references/` and are read from disk when poteto-mode or a playbook names them. Full index cost for all 58 would be about 3,300 tokens.
2. Tier knobs. The `REGISTERED` and `EXCLUDED` lists at the top of `sync.sh` are the single source of truth. Edit, re-run, update the plugin.
3. Exclusions. Nine skills are not shipped: six cursor-team-kit utilities (`deslop`, `fix-ci`, `fix-merge-conflicts`, `get-pr-comments`, `make-pr-easy-to-review`, `what-did-i-get-done`) and three thermos review skills (`thermos`, `thermo-nuclear-review`, `thermo-nuclear-code-quality-review`), per the packaging decision in the local development plan. Their subagent definitions are excluded with them.
4. Frontmatter normalization. `user-invocable: false` (a Claude Code field on the 24 principle skills) is stripped from every copy. The field stays maintained upstream.
5. Zcode adaptation. A generated `pstack-zcode` skill and a `zcode-tools.md` runtime mapping declare, rather than fake: tool-name mappings (Agent, TodoWrite, Read, Grep, Glob map one to one), single-model review panels (every model role inherits the session model on Zcode), the Cursor-only skip policy (verbatim: "Skipped: <step>. <reason>." then go on), and unsupported transcript-based skills.
6. Generated helper. `pstack-guide` (skill) and `SKILL-GUIDE.md` (human-readable) answer "which skill when" and are regenerated from the same tier lists, so they cannot drift.

## Install in Zcode

From a checkout of this repository:

```
zcode plugins marketplace add <path-to-this-checkout>
zcode plugins install pstack@pstack-local
```

Or add the repository through the Zcode app: Plugin Marketplace, Add, then install `pstack`. Plugin skills appear as `pstack:<name>` (for example `pstack:poteto-mode`).

For routing, add this line to your Zcode user instruction file (`~/.zcode/AGENTS.md`):

```
For non-trivial coding tasks, load and follow the poteto-mode skill; skip Cursor-only steps with a one-line note.
```

The port's routing hook is intentionally not shipped; routing comes from the instruction file.

## Build from source

`sync.sh` regenerates `pstack/`, `marketplace.json`, and `SKILL-GUIDE.md` from a clone of michael-denyer/pstack-claude. Clone resolution order: `$PSTACK_PORT_DIR`, `../../repo-port-denyer` (the local seed layout), `./repo-port-denyer` (this repository's layout), or a fresh shallow clone fetched into `./repo-port-denyer`.

```
./sync.sh
zcode plugins update pstack@pstack-local
```

After an upstream `git pull`, re-run `sync.sh`; it re-snapshots, re-normalizes, and rewrites both manifests with the new version and pin.

## Layout

| Path | What |
|---|---|
| `sync.sh` | Build script; tier knobs at the top |
| `pstack/` | The generated plugin (`skills/` 15 registered skills, `agents/` poteto-agent and comment-sicko, `.zcode-plugin/plugin.json`) |
| `pstack/skills/poteto-mode/references/` | The reference tier: `principles/` (24), `skills/` (21), `zcode-tools.md` |
| `marketplace.json` | Local marketplace definition (`pstack-local`) |
| `SKILL-GUIDE.md` | Human-readable "which skill when" (same content as the `pstack-guide` skill) |
| `LICENSE`, `NOTICE-skills.md` | MIT license and upstream provenance |

## License

MIT. Upstream notices: `pstack/LICENSE` (pstack, Lauren Tan) and `pstack/NOTICE-skills.md` (records the three upstream sources the port bundles). The packaging changes in this repository are also MIT.
