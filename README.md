# CustomPstack

Packaging of [pstack](https://github.com/cursor/plugins) for Zcode, Claude Code, claude.ai/Cowork, Codex, and Hermes. pstack is Lauren Tan's rigorous engineering skill stack for coding agents. One build script emits every target from one pinned port clone, and each harness consumes its native plugin or skill hierarchy. Skill content ships as the port wrote it; every packaging difference from upstream is listed in [DEVIATIONS.md](DEVIATIONS.md), with a verification command for each.

## Credits and provenance

This project only exists because of the work of others. In order of contribution:

| Work | Author | Source | License | Role in this repo |
|---|---|---|---|---|
| pstack (original) | Lauren Tan | https://github.com/cursor/plugins (folder `pstack`) | MIT | The original skill content and workflow design. All substantive skill text descends from this work. |
| pstack-claude (port) | Michael Denyer | https://github.com/michael-denyer/pstack-claude | MIT | Build-time translation of Cursor names to Claude Code names. The skill text shipped in `pstack/` and `pstack-cc/` is this port's content; the exact version and source pin are stamped in every manifest (0.9.138 @ `a12b047` at packaging time). |
| Multi-harness packaging | Dan Tembe | this repository | MIT | Per-harness manifests and hierarchies, two-tier skill exposure, frontmatter normalization, the Zcode and Hermes adaptations, and the `sync.sh` build script. |

Not affiliated with, endorsed by, or produced by Lauren Tan, Cursor, Michael Denyer, or Z.ai. All credit for the pstack methodology and skill content belongs to the original authors. This packaging is permitted by the MIT licenses of both upstream works, and the license notices travel with the content (`pstack/LICENSE`, `pstack/NOTICE-skills.md`, which records all three upstream sources).

## What this packaging changes

In short: the skills are not rewritten, but they are not all loaded the way upstream loads them.

1. Two-tier exposure. A small registered tier installs as real skills; everything else nests under `poteto-mode/references/` and is read from disk on demand. This cuts the standing per-session index cost by more than half.
2. Nine port skills are excluded (six cursor-team-kit utilities, three thermos review skills) plus the two thermos subagents.
3. The `user-invocable: false` frontmatter field is stripped from every copy.
4. Per-harness adaptation content is generated at build time: `pstack-zcode` + `zcode-tools.md` (Zcode), a `pstack-guide` index skill, and the `hermes/pstack-mode` router skill.
5. The port's SessionStart hooks and `models.json` are not shipped. Routing comes from instruction-file lines; role defaults stay stamped in the skill text.
6. The fifth target is a `dsh/` DeepSeek Harness bundle served by a skills provider, not a model router: this packaging writes no model configuration, children inherit the session model, and per-child agentPreset stays the operator's configuration.

[DEVIATIONS.md](DEVIATIONS.md) carries the full list, the reasons, the byte-identity proof for the shipped content, and a verification command for every claim. Tier knobs (`REGISTERED`, `REGISTERED_CC`, `EXCLUDED`) live at the top of `sync.sh` and are the single source of truth.

## Install per harness

- Zcode: `zcode plugins marketplace add <path-to-this-checkout>`, then `zcode plugins install pstack@pstack-local`. Or add the repository through the Zcode app. Skills appear as `pstack:<name>`.
- Claude Code: `claude plugin marketplace add dtembe/CustomPstack`, then `claude plugin install pstack@custom-pstack`.
- claude.ai / Cowork / Claude Desktop: Customize > Plugins > Add marketplace > `https://github.com/dtembe/CustomPstack`, then install `pstack`. Account-level: skills and agents load in chat and Cowork tasks.
- Codex: `codex plugin marketplace add dtembe/CustomPstack`, then `codex plugin add pstack@custom-pstack`. Skills appear as `$pstack:<name>`.
- Hermes: copy or symlink `hermes/pstack-mode/` into `~/.hermes/skills/software-development/`. One router skill; Hermes triggers it by description match.
- DeepSeek Harness: `dsh plugin --profile <name> add github:dtembe/CustomPstack#dsh-<version>` (or a local path add of this checkout). One bundle served by a skills provider; rollback is `dsh plugin --profile <name> remove custom-pstack-dsh`. Developer-preview software on a developer-preview harness (dsh 0.2.x).

### Routing

The port's SessionStart hook is intentionally not shipped (see [DEVIATIONS.md](DEVIATIONS.md), item 6). Auto-routing comes from one line in each harness's user instruction file (`~/.zcode/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.dsh/AGENTS.md`):

```
For non-trivial coding tasks, load and follow the poteto-mode skill; skip Cursor-only steps with a one-line note.
```

## Build from source

`sync.sh` regenerates every target from a clone of michael-denyer/pstack-claude. Clone resolution order: `$PSTACK_PORT_DIR`, `../../repo-port-denyer` (the local seed layout), `./repo-port-denyer` (this repository's layout), or a fresh shallow clone fetched into `./repo-port-denyer`.

```
./sync.sh
```

After an upstream `git pull`, re-run `./sync.sh`; it re-snapshots, re-normalizes, and rewrites all manifests with the new version and pin. Then update or reinstall the plugin in each harness you use. The Zcode target's output is the reference copy; a change that alters it unintentionally is a bug.

## Layout

| Path | What |
|---|---|
| `sync.sh` | Build script; tier knobs at the top; emits all targets in one run |
| `pstack/` | Zcode plugin (`.zcode-plugin/plugin.json`, 15 registered skills, reference tier, 2 agents) |
| `pstack-cc/` | Shared Claude Code + Codex plugin (`.claude-plugin/` and `.codex-plugin/` manifests, same skills tree, 2 agents) |
| `pstack*/skills/poteto-mode/references/` | Reference tier: `principles/` (24), `skills/` (20 to 21), per-runtime tool mappings from the port |
| `hermes/pstack-mode/` | One Hermes router skill (5731-char body, 23 playbooks, 24 principles, delegate briefs, harness mapping) |
| `dsh/` + `package.json` | DeepSeek Harness bundle (skills provider `lib/index.mjs`, `cordis.patch.yml`, 14 registered skills, reference tier, smoke test) and the tracked npm manifest that declares it |
| `marketplace.json` | Zcode marketplace definition (`pstack-local`) |
| `.claude-plugin/marketplace.json` | Claude marketplace definition (`custom-pstack`) |
| `.agents/plugins/marketplace.json` | Codex marketplace definition (`custom-pstack`, Denyer format) |
| `SKILL-GUIDE.md` | Human-readable "which skill when" (mirrors the Zcode `pstack-guide` skill) |
| `DEVIATIONS.md` | Every difference from upstream, with verification commands |
| `LICENSE`, `NOTICE-skills.md` | MIT license and upstream provenance |

## License

MIT. Upstream notices: `pstack/LICENSE` (pstack, Lauren Tan) and `pstack/NOTICE-skills.md` (records the three upstream sources the port bundles). The packaging changes in this repository are also MIT.
