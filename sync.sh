#!/bin/bash
# pstack multi-harness plugin build.
# Regenerates every publish target from the michael-denyer/pstack-claude clone:
#   pstack/     Zcode plugin (registered tier + generated Zcode adaptation)
#   pstack-cc/  shared Claude Code / Codex plugin (port-native flavor)
#   hermes/     one Hermes router skill (pstack-mode)
#   dsh/        DeepSeek Harness bundle (skills provider + cordis patch) and
#               the tracked root package.json that declares it
#   .claude-plugin/marketplace.json and .agents/plugins/marketplace.json
#               root manifests for the shared pstack-cc tree
# The clone is located in this order: $PSTACK_PORT_DIR, a sibling of the seed
# root (../../repo-port-denyer, the local seed layout), ./repo-port-denyer
# (published repository layout), or a fresh shallow clone.
# Knobs below: EXCLUDED = never shipped by any target; REGISTERED / GENERATED =
# the Zcode tier; REGISTERED_CC / GENERATED_CC = the shared Claude Code / Codex
# tier; REGISTERED_DSH / GENERATED_DSH = the DeepSeek Harness bundle tier.
# Every other pstack-proper skill ships as an on-demand reference under
# poteto-mode/references/ (Zcode, pstack-cc, and dsh) or as a Hermes principle leaf.
# Edit the knobs, re-run this script, reinstall/update per harness.
#
# Rules implemented (PSTACK-DEV-PLAN.md section 4 and the CC/Hermes extension):
#   - Zcode: single-model panels declared, never faked
#   - pstack-cc: port text kept as-is (Claude Code and Codex take real
#     per-subagent models; the port carries the role defaults)
#   - Cursor-only steps skipped with a one-line note (verbatim policy)
#   - no model config changes
#   - user-invocable: false stripped from all copies (Claude-only field; Dan, 2026-11-13)
#   - dsh: a rank-600 skills provider serves the tier; the bundle writes no
#     model or reasoning overrides (children inherit the session default)
set -euo pipefail

# Resolve locations relative to this script, so the same script runs from the
# seed (builds/zcode/), from a worktree, and from a published repository
# checkout. Env override wins. Missing port clone is fetched as a shallow clone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT_DIR="${PSTACK_PORT_DIR:-}"
if [ -z "$PORT_DIR" ]; then
  for candidate in "$SCRIPT_DIR/repo-port-denyer" "$SCRIPT_DIR/../../repo-port-denyer"; do
    if [ -d "$candidate/plugins/pstack" ]; then PORT_DIR="$(cd "$candidate" && pwd)"; break; fi
  done
fi
if [ -z "$PORT_DIR" ]; then
  echo "port clone not found; cloning michael-denyer/pstack-claude into $SCRIPT_DIR/repo-port-denyer"
  git clone --depth 1 https://github.com/michael-denyer/pstack-claude.git "$SCRIPT_DIR/repo-port-denyer"
  PORT_DIR="$SCRIPT_DIR/repo-port-denyer"
fi
SRC="$PORT_DIR"
SRC_SKILLS="$SRC/plugins/pstack/skills"

EXCLUDED="deslop fix-ci fix-merge-conflicts get-pr-comments make-pr-easy-to-review what-did-i-get-done thermos thermo-nuclear-review thermo-nuclear-code-quality-review"
REGISTERED="poteto-mode unslop tdd arena swarm interrogate sharpen technical-writing no-comments babysit architect blast-radius show-me-your-work"
GENERATED="pstack-zcode pstack-guide"
# Shared Claude Code / Codex tier: the Zcode registered set plus setup-pstack.
# No pstack-zcode here: that adaptation is Zcode-only.
REGISTERED_CC="$REGISTERED setup-pstack"
GENERATED_CC="pstack-guide"
# DeepSeek Harness bundle tier: the shared set minus setup-pstack. setup-pstack
# stays a reference leaf on purpose: its sheet paths are Claude/Codex specific
# and this build writes no model configuration.
REGISTERED_DSH="$REGISTERED"
GENERATED_DSH="pstack-guide"
# dsh truncates catalog descriptions at this bound (skills.md,
# catalogDescriptionMaxLength default); the guard below fails the build over it.
DSH_DESC_MAX=500

VER="$(cat "$SRC/VERSION" 2>/dev/null || echo unknown)"
SHA="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
case "$VER$SHA" in
  *[!0-9A-Za-z._-]*) echo "FATAL: unexpected VERSION or SHA: '$VER' '$SHA'"; exit 1;;
esac
[ -n "$VER" ] || { echo "FATAL: empty VERSION in clone"; exit 1; }

is_excluded()      { case " $EXCLUDED " in      *" $1 "*) return 0;; *) return 1;; esac; }
is_registered()    { case " $REGISTERED " in    *" $1 "*) return 0;; *) return 1;; esac; }
is_generated()     { case " $GENERATED " in     *" $1 "*) return 0;; *) return 1;; esac; }
is_registered_cc() { case " $REGISTERED_CC " in *" $1 "*) return 0;; *) return 1;; esac; }
is_generated_cc()  { case " $GENERATED_CC " in  *" $1 "*) return 0;; *) return 1;; esac; }
is_registered_dsh() { case " $REGISTERED_DSH " in *" $1 "*) return 0;; *) return 1;; esac; }
is_generated_dsh()  { case " $GENERATED_DSH " in  *" $1 "*) return 0;; *) return 1;; esac; }
is_principle()     { case "$1" in principle-*) return 0;; *) return 1;; esac; }

# Strip the Claude-only field from a SKILL.md copy (portable: temp file + mv,
# works under BSD and GNU sed).
normalize() { sed -e '/^user-invocable:/d' "$1" > "$1.norm.tmp" && mv "$1.norm.tmp" "$1"; }

# One-phrase when-to-use for the Hermes playbook index, generated from the
# files actually copied. Unknown files get a generic line, never silence.
playbook_when() {
  case "$1" in
    authoring-a-skill) echo "writing or editing a SKILL.md";;
    autonomous-run) echo "a long task driven to done without stopping";;
    autopilot-full) echo "a queue of independent PRs with full autonomy";;
    autopilot-stack) echo "a queue of stacked PRs with full autonomy";;
    babysit) echo "driving a PR or a stack to merge-ready";;
    bug-fix) echo "reproduce, root-cause, and fix a reported defect";;
    eval) echo "testing how a skill or prompt change affects behavior";;
    feature) echo "new or changed behavior from a named data shape";;
    hillclimb) echo "sustained improvement of one metric against a target";;
    investigation) echo "a read-only how or why question";;
    multi-phase-plan) echo "work spanning phases or stacked PRs";;
    opening-a-pr) echo "opened at the end of every playbook";;
    orchestrate) echo "a standing multi-PR program under one coordinator";;
    pause-safely) echo "suspending in-flight work for a clean resume";;
    perf-issue) echo "tracing and fixing a measured slowness";;
    prototype) echo "a throwaway sketch to settle a design call";;
    refactoring) echo "a behavior-preserving structure change";;
    runtime-forensics) echo "diagnosing a live symptom from instrumentation";;
    session-pickup) echo "resuming a prior agent's in-flight work";;
    shipping) echo "verifying a green stack, then landing it bottom-up";;
    trace-forensics) echo "diagnosing a captured profiling artifact";;
    visual-parity) echo "pixel-exact UI equivalence";;
    worktree-cleanup) echo "pruning merged worktrees and stale simulators";;
    *) echo "read the file for when to use it";;
  esac
}

# Shared reference-tier copy used by the Zcode and pstack-cc targets: full-dir
# copies for registered skills, principles and other leaves nested under
# poteto-mode/references/. Caller sets OUT, the registered/generated testers,
# PRIN and REFS.
copy_reference_tier() {
  mkdir -p "$PRIN" "$REFS"
  ref_principles=""
  ref_skills=""
  for d in "$SRC_SKILLS"/*/; do
    n="$(basename "$d")"
    is_excluded "$n" && continue
    is_registered_target "$n" && continue
    is_generated_target "$n" && continue
    [ -f "$d/SKILL.md" ] || continue
    if is_principle "$n"; then
      cp "$d/SKILL.md" "$PRIN/$n.md"
      normalize "$PRIN/$n.md"
      ref_principles="$ref_principles$n\n"
    else
      cp -R "$d" "$REFS/$n"
      normalize "$REFS/$n/SKILL.md"
      ref_skills="$ref_skills$n\n"
    fi
  done
}

echo "pstack build: source pin $SHA, version $VER"

# =============================================================================
# Target 1: Zcode (pstack/, root marketplace.json, SKILL-GUIDE.md)
# =============================================================================
build_zcode() {
  OUT="$SCRIPT_DIR/pstack"

  # --- clean rebuild -----------------------------------------------------------
  rm -rf "$OUT"
  mkdir -p "$OUT/.zcode-plugin" "$OUT/skills" "$OUT/agents"

  # --- registered skills: full directory copies --------------------------------
  for s in $REGISTERED; do
    [ -d "$SRC_SKILLS/$s" ] || { echo "FATAL: registered skill missing in clone: $s"; exit 1; }
    cp -R "$SRC_SKILLS/$s" "$OUT/skills/$s"
    normalize "$OUT/skills/$s/SKILL.md"
  done

  # --- reference tier under poteto-mode/references/ ----------------------------
  PM_REF="$OUT/skills/poteto-mode/references"
  PRIN="$PM_REF/principles"
  REFS="$PM_REF/skills"
  is_registered_target() { is_registered "$1"; }
  is_generated_target()  { is_generated "$1"; }
  copy_reference_tier

  # --- Zcode runtime mapping, using the port's own per-runtime reference slot ---
  cat > "$PM_REF/zcode-tools.md" <<'EOF'
# Zcode runtime mapping

Build-time adaptation (builds/zcode/sync.sh). pstack bodies are Claude Code
native; Zcode maps almost 1:1.

| Claude Code primitive | Zcode |
|---|---|
| Agent tool spawn | Agent tool. poteto-mode delegates use subagent_type `pstack:poteto-agent` (falls back to the default agent if that type is absent). Resume rules in poteto-mode still apply. |
| TaskCreate / TodoWrite | TodoWrite (same name). |
| Read / Grep / Glob | Same names. |
| AskQuestion | Children cannot ask. The parent chat asks the user; children get full context up front. |
| environment: "cloud" | Omit. For isolation, pass the child a git worktree path. |
| Model slugs (opus/fable/sonnet/haiku tiers) | Every role inherits the session model. Review panels (arena, interrogate) are single-model on Zcode; say so plainly, never claim diversity. Never edit model config without an explicit ask from the operator. |
| Transcript file reads (recall, ketchup, correct, reflect, automate-me) | Not supported on Zcode. Use the skip policy below. |
| Cursor Automations, Bugbot, cloud agents, /loop | Skip with the one-line policy below. |
| Plugin rules file pstack-models.mdc | Role lines live in this plugin's pstack-zcode skill; router reads them. |

Skip policy (verbatim): When a step needs one, put one line in your reply,
`Skipped: <step>. <reason>.`, then go on. Do not stop, ask, or retry.
EOF

  # --- declared adaptation note appended to the copied poteto-mode SKILL.md ----
  cat >> "$OUT/skills/poteto-mode/SKILL.md" <<'EOF'

<!-- pstack-zcode-adaptation: generated by builds/zcode/sync.sh; regenerate, do not hand-edit -->

## Zcode adaptation

This copy runs on Zcode (pstack plugin for Zcode).

- Tool names map 1:1 (Agent, TodoWrite, Read/Grep/Glob). Full mapping: `references/zcode-tools.md` beside this file.
- Leaf skills without their own Zcode entry live here: principles at `references/principles/<name>.md`, other skills at `references/skills/<name>/SKILL.md`. Read them with the file tool when this skill or a playbook names them.
- Model roles: every role inherits the session model; review panels are single-model. Declare it, do not fake diversity.
- Cursor-only steps: put one line in your reply, `Skipped: <step>. <reason>.`, then go on. Do not stop, ask, or retry.
- More Zcode differences and troubleshooting: the `pstack-zcode` skill.
EOF

  # --- generated skill 1: pstack-zcode ------------------------------------------
  mkdir -p "$OUT/skills/pstack-zcode"
  cat > "$OUT/skills/pstack-zcode/SKILL.md" <<EOF
---
name: pstack-zcode
description: Zcode adaptation notes for the pstack plugin. Read when a pstack skill or playbook hits a Zcode-specific difference (tools, subagents, models, transcripts, setup-pstack) or when configuring or troubleshooting pstack on Zcode.
---

# pstack on Zcode

This plugin ships Lauren Tan's pstack via michael-denyer/pstack-claude, port version __VER__, source pin __SHA__. Built by sync.sh in this repository; regenerate, do not hand-edit.

## Tool and primitive map

See poteto-mode's \`references/zcode-tools.md\` for the full table. Short form: Agent tool delegates use \`pstack:poteto-agent\` (fallback: default agent); TodoWrite, Read, Grep, Glob are unchanged; children cannot ask questions (the parent chat asks); no cloud environments (use git worktree paths).

## Model roles

Every pstack model role inherits the session model. Review panels (arena, interrogate) are single-model on Zcode. Say so plainly; do not claim diversity. Never edit model configuration without an explicit ask from the operator.

## Cursor-only skip policy (verbatim)

When a step needs one, put one line in your reply, \`Skipped: <step>. <reason>.\`, then go on. Do not stop, ask, or retry.

## Other Zcode differences

- setup-pstack: do not run it on Zcode. Model roles are fixed by the rules above.
- poteto-agent's cache-path fallback searches Claude Code plugin paths; on Zcode the parent must pass the absolute path to poteto-mode's SKILL.md.
- Reference-tier leaves (not registered as Zcode skills): principles at \`skills/poteto-mode/references/principles/<name>.md\`, other skills at \`skills/poteto-mode/references/skills/<name>/SKILL.md\`. Read on demand.
- Not shipped (cursor-team-kit and thermos extras; packaging decision recorded in the repository README): __EXCLUDED__.
- Update path: git pull in repo-port-denyer, re-run sync.sh, then \`zcode plugins update pstack@pstack-local\`.
EOF
  # In-place sed flags differ between BSD and GNU; substitute via temp file + mv.
  ZS="$OUT/skills/pstack-zcode/SKILL.md"
  sed -e "s/__VER__/$VER/g" -e "s/__SHA__/$SHA/g" -e "s/__EXCLUDED__/$(echo $EXCLUDED | sed 's/ /, /g')/g" "$ZS" > "$ZS.norm.tmp" && mv "$ZS.norm.tmp" "$ZS"

  # --- generated skill 2: pstack-guide (+ human-readable SKILL-GUIDE.md) --------
  GUIDE_BODY="$OUT/skills/pstack-guide/SKILL.md"
  mkdir -p "$OUT/skills/pstack-guide"
  cat > "$GUIDE_BODY" <<'EOF'
---
name: pstack-guide
description: Index of the pstack skills available in this Zcode plugin and when to invoke each. Use when unsure which pstack skill applies, when asked what pstack provides, or to find a pstack skill or principle by name.
---

# pstack skill guide (Zcode)

pstack is Lauren Tan's rigorous engineering stack (MIT), shipped for Zcode via the michael-denyer port. Two tiers: registered skills below are always visible to the model (invoke with /name or describe the need); reference leaves load only when read from disk.

## Routing rules

1. Non-trivial coding task: nothing to invoke by hand. poteto-mode auto-triggers (the user-level instruction file asks for it), owns the playbook and todo list, and pulls principles as needed.
2. Know the specific skill: invoke /name from the registered table.
3. Not sure: read the tables below; the descriptions are the port's own. Reference leaves are listed at the bottom with their on-disk paths.

## Registered skills

| Skill | Invoke | First line of its description |
|---|---|---|
EOF

  # auto rows for registered skills from their copied frontmatter
  for s in pstack-zcode pstack-guide $REGISTERED; do
    f="$OUT/skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    desc="$(awk '/^description:/{sub(/^description:[ ]*/,""); gsub(/^"|"$/,""); print; exit}' "$f")"
    first="$(printf '%s' "$desc" | cut -c1-160 | sed -e 's/\\//g' -e 's/|/\\|/g')"
    printf '| %s | /%s | %s |\n' "$s" "$s" "$first" >> "$GUIDE_BODY"
  done

  cat >> "$GUIDE_BODY" <<'EOF'

## Reference leaves (read on demand, no auto-trigger)

Principles live at `poteto-mode/references/principles/<name>.md`; other leaves at `poteto-mode/references/skills/<name>/SKILL.md` (paths relative to the poteto-mode skill directory).

### Principles
EOF
  printf '%b' "$ref_principles" | sed '/^$/d' | awk '{printf "- %s\n", $0}' >> "$GUIDE_BODY"
  cat >> "$GUIDE_BODY" <<'EOF'

### Other skills
EOF
  printf '%b' "$ref_skills" | sed '/^$/d' | awk '{printf "- %s\n", $0}' >> "$GUIDE_BODY"
  cat >> "$GUIDE_BODY" <<EOF

## Not in this build

Cursor-team-kit extras (deslop, fix-ci, fix-merge-conflicts, get-pr-comments, make-pr-easy-to-review, what-did-i-get-done) and the thermos review pack (thermos, thermo-nuclear-review, thermo-nuclear-code-quality-review) are excluded by this repository's packaging decision (see the README, "What this packaging changes").

Source: port version $VER, pin $SHA. Regenerated by sync.sh in this repository; edit that script's tier lists and re-run to promote or demote skills.
EOF

  # human-readable copy (frontmatter stripped via awk; BSD sed range gotcha avoided)
  awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next} fm==1 && /^---[[:space:]]*$/ {fm=2; next} fm!=1 {print}' "$GUIDE_BODY" > "$SCRIPT_DIR/SKILL-GUIDE.md.tmp"
  { echo "<!-- Generated by sync.sh on $(date +%Y-%m-%d). Do not hand-edit; re-run sync.sh. -->"; echo; cat "$SCRIPT_DIR/SKILL-GUIDE.md.tmp"; } > "$SCRIPT_DIR/SKILL-GUIDE.md" && rm "$SCRIPT_DIR/SKILL-GUIDE.md.tmp"

  # --- agents (verbatim; verified no model frontmatter) -------------------------
  cp "$SRC/plugins/pstack/agents/poteto-agent.md" "$OUT/agents/"
  cp "$SRC/plugins/pstack/agents/comment-sicko.md" "$OUT/agents/"

  # --- licenses / provenance (root copies make the repo self-describing) --------
  cp "$SRC/plugins/pstack/LICENSE" "$OUT/LICENSE" 2>/dev/null || cp "$SRC/LICENSE" "$OUT/LICENSE"
  cp "$SRC/NOTICE-skills.md" "$OUT/NOTICE-skills.md"
  cp "$OUT/LICENSE" "$SCRIPT_DIR/LICENSE"
  cp "$OUT/NOTICE-skills.md" "$SCRIPT_DIR/NOTICE-skills.md"

  # --- manifests ----------------------------------------------------------------
  cat > "$OUT/.zcode-plugin/plugin.json" <<EOF
{
  "name": "pstack",
  "version": "$VER",
  "description": "pstack for Zcode: Lauren Tan's rigorous agent-workflow skills (poteto-mode and stack) via michael-denyer/pstack-claude $VER @ $SHA. Two-tier build: registered skills plus on-demand reference leaves. Single-model panels declared; Cursor-only steps skipped with a one-line note.",
  "author": { "name": "Dan Tembe" },
  "license": "MIT",
  "skills": "skills",
  "agents": "agents"
}
EOF

  cat > "$SCRIPT_DIR/marketplace.json" <<EOF
{
  "name": "pstack-local",
  "owner": { "name": "Dan Tembe" },
  "plugins": [
    {
      "name": "pstack",
      "source": "./pstack",
      "version": "$VER",
      "description": "pstack for Zcode (via michael-denyer/pstack-claude $VER @ $SHA).",
      "category": "developer-tools"
    }
  ]
}
EOF

  # --- summary ------------------------------------------------------------------
  reg_count="$(ls "$OUT/skills" | wc -l | tr -d ' ')"
  prin_count="$(ls "$PRIN" | wc -l | tr -d ' ')"
  ref_count="$(ls "$REFS" | wc -l | tr -d ' ')"
  echo "zcode target: registered skills $reg_count (incl. pstack-zcode, pstack-guide), reference principles $prin_count, reference skills $ref_count"
  echo "zcode output: $OUT"
}

# =============================================================================
# Target 2: shared Claude Code / Codex plugin (pstack-cc/, port-native flavor)
# =============================================================================
build_cc() {
  OUT="$SCRIPT_DIR/pstack-cc"

  # --- clean rebuild -----------------------------------------------------------
  rm -rf "$OUT"
  mkdir -p "$OUT/.claude-plugin" "$OUT/.codex-plugin" "$OUT/skills" "$OUT/agents"

  # --- registered skills: full directory copies --------------------------------
  for s in $REGISTERED_CC; do
    [ -d "$SRC_SKILLS/$s" ] || { echo "FATAL: registered skill missing in clone: $s"; exit 1; }
    cp -R "$SRC_SKILLS/$s" "$OUT/skills/$s"
    normalize "$OUT/skills/$s/SKILL.md"
  done

  # --- reference tier: same mechanics as the Zcode build ------------------------
  # No zcode-tools.md and no adaptation footer here: the port's own per-runtime
  # references/ (codex-tools.md and friends) arrive with the poteto-mode copy.
  PM_REF="$OUT/skills/poteto-mode/references"
  PRIN="$PM_REF/principles"
  REFS="$PM_REF/skills"
  is_registered_target() { is_registered_cc "$1"; }
  is_generated_target()  { is_generated_cc "$1"; }
  copy_reference_tier

  # --- agents, licenses ---------------------------------------------------------
  cp "$SRC/plugins/pstack/agents/poteto-agent.md" "$OUT/agents/"
  cp "$SRC/plugins/pstack/agents/comment-sicko.md" "$OUT/agents/"
  cp "$SRC/plugins/pstack/LICENSE" "$OUT/LICENSE" 2>/dev/null || cp "$SRC/LICENSE" "$OUT/LICENSE"
  cp "$SRC/NOTICE-skills.md" "$OUT/NOTICE-skills.md"

  # --- manifests ----------------------------------------------------------------
  cat > "$OUT/.claude-plugin/plugin.json" <<EOF
{
  "name": "pstack",
  "displayName": "pstack (Claude Code / Codex build)",
  "version": "$VER",
  "description": "pstack for Claude Code and Codex: Lauren Tan's rigorous agent-workflow skills via michael-denyer/pstack-claude $VER @ $SHA. Two-tier build: registered skills plus on-demand reference leaves. Cursor-only steps skipped with a one-line note.",
  "author": { "name": "Dan Tembe", "url": "https://github.com/dtembe" },
  "homepage": "https://github.com/dtembe/CustomPstack",
  "repository": "https://github.com/dtembe/CustomPstack",
  "license": "MIT",
  "keywords": ["pstack", "poteto-mode", "workflow", "principles", "agent-style", "subagents", "unslop"]
}
EOF

  cat > "$OUT/.codex-plugin/plugin.json" <<EOF
{
  "name": "pstack",
  "version": "$VER",
  "description": "pstack for Claude Code and Codex: Lauren Tan's rigorous agent-workflow skills via michael-denyer/pstack-claude $VER @ $SHA. Two-tier build: registered skills plus on-demand reference leaves. Cursor-only steps skipped with a one-line note. Skills are shared with the Claude Code build; on Codex, tool names resolve via skills/poteto-mode/references/codex-tools.md.",
  "author": { "name": "Dan Tembe", "url": "https://github.com/dtembe" },
  "homepage": "https://github.com/dtembe/CustomPstack",
  "repository": "https://github.com/dtembe/CustomPstack",
  "license": "MIT",
  "keywords": ["pstack", "poteto-mode", "workflow", "principles", "agent-style", "subagents", "unslop", "codex"],
  "skills": "./skills/",
  "interface": {
    "displayName": "pstack",
    "shortDescription": "Rigorous, parallelizable agent workflows: go deep first, write less, verify everything",
    "longDescription": "pstack guides agent work through poteto-mode's principles, parallel design exploration (architect/arena), adversarial multi-model review (interrogate), root-cause debugging, prose deslopping, and verified delivery. On Codex, tool names resolve via the codex-tools mapping.",
    "developerName": "Dan Tembe (port of Lauren Tan's pstack)",
    "category": "Developer Tools",
    "capabilities": ["Interactive", "Read", "Write"],
    "defaultPrompt": ["Work on this in poteto-mode.", "Interrogate this diff with multiple models."],
    "websiteURL": "https://github.com/dtembe/CustomPstack"
  }
}
EOF

  # --- generated skill: pstack-guide (Claude Code / Codex) ----------------------
  GUIDE_BODY="$OUT/skills/pstack-guide/SKILL.md"
  mkdir -p "$OUT/skills/pstack-guide"
  cat > "$GUIDE_BODY" <<'EOF'
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
EOF

  for s in pstack-guide $REGISTERED_CC; do
    f="$OUT/skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    desc="$(awk '/^description:/{sub(/^description:[ ]*/,""); gsub(/^"|"$/,""); print; exit}' "$f")"
    first="$(printf '%s' "$desc" | cut -c1-160 | sed -e 's/\\//g' -e 's/|/\\|/g')"
    printf '| %s | /%s | %s |\n' "$s" "$s" "$first" >> "$GUIDE_BODY"
  done

  cat >> "$GUIDE_BODY" <<'EOF'

## Reference leaves (read on demand, no auto-trigger)

Principles live at `poteto-mode/references/principles/<name>.md`; other leaves at `poteto-mode/references/skills/<name>/SKILL.md` (paths relative to the poteto-mode skill directory).

### Principles
EOF
  printf '%b' "$ref_principles" | sed '/^$/d' | awk '{printf "- %s\n", $0}' >> "$GUIDE_BODY"
  cat >> "$GUIDE_BODY" <<'EOF'

### Other skills
EOF
  printf '%b' "$ref_skills" | sed '/^$/d' | awk '{printf "- %s\n", $0}' >> "$GUIDE_BODY"
  cat >> "$GUIDE_BODY" <<EOF

## Not in this build

Cursor-team-kit extras (deslop, fix-ci, fix-merge-conflicts, get-pr-comments, make-pr-easy-to-review, what-did-i-get-done) and the thermos review pack (thermos, thermo-nuclear-review, thermo-nuclear-code-quality-review) are excluded by this repository's packaging decision (see the README, "What this packaging changes").

Source: port version $VER, pin $SHA. Regenerated by sync.sh in this repository; edit that script's tier lists and re-run to promote or demote skills.
EOF

  # --- root marketplace manifests for the shared tree ---------------------------
  mkdir -p "$SCRIPT_DIR/.claude-plugin" "$SCRIPT_DIR/.agents/plugins"
  cat > "$SCRIPT_DIR/.claude-plugin/marketplace.json" <<EOF
{
  "name": "custom-pstack",
  "owner": { "name": "Dan Tembe", "url": "https://github.com/dtembe" },
  "description": "pstack for Claude Code and claude.ai/Cowork (via michael-denyer/pstack-claude $VER @ $SHA).",
  "plugins": [
    {
      "name": "pstack",
      "source": "./pstack-cc",
      "description": "If you want to go fast, go deep first. pstack helps you write less, but higher quality code. rigorous agent workflows you can parallelize with confidence. Original pstack by Lauren Tan (poteto).",
      "version": "$VER"
    }
  ]
}
EOF

  cat > "$SCRIPT_DIR/.agents/plugins/marketplace.json" <<'EOF'
{
  "name": "custom-pstack",
  "interface": { "displayName": "pstack" },
  "plugins": [
    {
      "name": "pstack",
      "source": { "source": "local", "path": "./pstack-cc" },
      "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL", "products": ["CODEX"] },
      "category": "Developer Tools"
    }
  ]
}
EOF

  # --- summary ------------------------------------------------------------------
  reg_cc_count="$(ls "$OUT/skills" | wc -l | tr -d ' ')"
  prin_cc_count="$(ls "$PRIN" | wc -l | tr -d ' ')"
  ref_cc_count="$(ls "$REFS" | wc -l | tr -d ' ')"
  echo "pstack-cc target: skills $reg_cc_count (incl. pstack-guide), reference principles $prin_cc_count, reference skills $ref_cc_count"
  echo "pstack-cc output: $OUT"
}

# =============================================================================
# Target 3: Hermes router skill (hermes/pstack-mode/)
# =============================================================================
build_hermes() {
  OUT="$SCRIPT_DIR/hermes"
  rm -rf "$OUT"
  HM="$OUT/pstack-mode"
  HM_REF="$HM/references"
  mkdir -p "$HM_REF/playbooks" "$HM_REF/principles" "$HM_REF/agents"

  # --- playbooks and principle leaves (inputs for the SKILL.md indexes) ---------
  for f in "$SRC_SKILLS/poteto-mode/playbooks/"*.md; do
    cp "$f" "$HM_REF/playbooks/"
  done
  hermes_prin_list=""
  for d in "$SRC_SKILLS"/principle-*/; do
    n="$(basename "$d")"
    cp "$d/SKILL.md" "$HM_REF/principles/$n.md"
    normalize "$HM_REF/principles/$n.md"
    hermes_prin_list="$hermes_prin_list$n, "
  done
  hermes_prin_list="${hermes_prin_list%, }"

  # --- router SKILL.md (Hermes triggers skills by description match only) -------
  HM_SKILL="$HM/SKILL.md"
  cat > "$HM_SKILL" <<'EOF'
---
name: pstack-mode
description: Rigorous engineering mode: repro-first bug fixes, verify against the running app, multi-agent review, PR babysit, autonomous/overnight runs. Use for non-trivial coding tasks in any repo.
---

# pstack mode for Hermes

This skill condenses poteto-mode (Lauren Tan's pstack) for Hermes. Read a detail file under `references/` before you apply what it covers. Tool mapping: `references/harness-hermes.md`.

## When to use

Use this mode for every non-trivial coding task in any repo: features, refactors, bug fixes, perf work, PR babysitting, review, and long autonomous runs. Skip it for one-line edits and pure lookups.

## First message

Open the task by restating, in your own words, the user's goal, the problem they are solving, and the smallest change you expect to make. Do not wait for confirmation. If evidence rules out the change the user asked for, show it and stop.

## Cursor-only steps

When a step needs one, put one line in your reply, `Skipped: <step>. <reason>.`, then go on. Do not stop, ask, or retry.

## Playbooks

Match the task to a playbook and read the file before you run its steps.

EOF
  for f in "$HM_REF/playbooks/"*.md; do
    b="$(basename "$f" .md)"
    printf -- '- %s: %s. references/playbooks/%s.md\n' "$b" "$(playbook_when "$b")" "$b" >> "$HM_SKILL"
  done

  cat >> "$HM_SKILL" <<'EOF'

## Principles

Read a leaf before you apply it. Each leaf is one file, `references/principles/<name>.md`.

EOF
  printf '%s\n' "$hermes_prin_list" >> "$HM_SKILL"

  cat >> "$HM_SKILL" <<'EOF'

## Autonomy

Reversible work proceeds without asking, including external actions such as team chat, ticket updates, and kicking off evals. Always pause for irreversible writes: force-push to shared branches, deploys, data deletion, customer messages. An explicit "run until done" grant keeps you going, and gates the user named still pause.

## Delegation

Spawn subwork with `delegate_task`. Put the goal plus full context in the brief; children cannot ask questions, so the brief carries absolute file paths, the task, and the constraints. The parent executes any step that needs the human. Prefer a fresh delegate with consolidated scope over resuming one. The self-report rule: a delegate's "fixed" is unverified until you rerun the repro yourself. Brief templates: `references/agents/poteto-agent-brief.md`, `references/agents/comment-sicko-brief.md`. Field mapping: `references/harness-hermes.md`.

## Reply style

Short declarative sentences. No long-dash character anywhere. No mid-sentence colon connectors. Label every claim measured, inferred, or guess in the same sentence. Never fabricate a link or citation. Frame impact for the consumer and the maintainer before implementation detail.

## Models

All model roles inherit the session model. Review panels are single-model; say so plainly, never claim diversity. Never edit model configuration without the operator asking. Role sheet: `references/pstack-models.md`.
EOF

  skill_chars="$(wc -c < "$HM_SKILL" | tr -d ' ')"
  [ "$skill_chars" -lt 8000 ] || { echo "FATAL: hermes SKILL.md is $skill_chars chars (limit 8000); trim the router"; exit 1; }

  # --- harness mapping ------------------------------------------------------------
  cat > "$HM_REF/harness-hermes.md" <<'EOF'
# pstack in Hermes

Build-time adaptation (sync.sh in this repository). pstack skill bodies are Claude Code native. In Hermes, read this file once per session and map each Cursor or Claude Code name with the table below. Port version __VER__, pin __SHA__.

| Cursor or Claude Code | Hermes |
|---|---|
| `Task` spawn | `delegate_task` (goal + full context in the brief; children cannot ask questions) |
| `AskQuestion` | `clarify` (parent only) |
| TodoWrite / todolist | `todo_list` |
| Run another pstack skill (`/name` or "the **name** skill") | `read_file` the matching file under this skill's `references/` and follow it |
| `Grep`, `Glob` | `search_files` |
| Model slugs in briefs | Omit. Children inherit the parent model. Pin `delegation.model` only with the operator's explicit ask. |
| `environment: "cloud"` | Omit. Give the child a git worktree path for isolation. |
| Cursor Automations, Bugbot, Cursor cloud agents, `/loop` | Skip with the policy below. |
| Transcript-reading skills (recall, ketchup, correct, reflect, automate-me) | `session_search` |

Hermes sessions are searched with `session_search`, not transcript files.

## Skip policy (verbatim)

When a step needs one, put one line in your reply, `Skipped: <step>. <reason>.`, then go on. Do not stop, ask, or retry.

## Not supported in Hermes

ketchup-video, make-bot-ui, statechart, benny/Automations, setup-pstack. These have no Hermes mapping; skip steps that need them with the policy above. setup-pstack writes runtime model-rule files, and the role sheet here is `references/pstack-models.md`, fixed at build time.
EOF
  sed -e "s/__VER__/$VER/g" -e "s/__SHA__/$SHA/g" "$HM_REF/harness-hermes.md" > "$HM_REF/harness-hermes.md.norm.tmp" && mv "$HM_REF/harness-hermes.md.norm.tmp" "$HM_REF/harness-hermes.md"

  # --- model role sheet -----------------------------------------------------------
  cat > "$HM_REF/pstack-models.md" <<'EOF'
# pstack model roles (Hermes)

Review panels (arena, architect, interrogate) run on one model in Hermes. That is declared, not faked: say the panel was single-model, never claim diversity.

| Role | Value on Hermes |
|---|---|
| feature | inherit parent model |
| refactoring | inherit parent model |
| bug-fix | inherit parent model |
| perf-issue | inherit parent model |
| hillclimb | inherit parent model |
| judgment and prose | inherit parent model |
| strongest judgment | inherit parent model |
| swarm workers | inherit parent model |
| arena / architect / interrogate panel seats | inherit parent model |

Standing rule: never edit model configuration (a `delegation.model` pin, a model slug in a delegate brief, or this sheet) without the operator's explicit ask.
EOF

  # --- delegate brief templates (rewritten from the port's agent definitions) ----
  cat > "$HM_REF/agents/poteto-agent-brief.md" <<'EOF'
# poteto-agent delegate brief (Hermes template)

What this delegate is for: a code-writing or helper delegate inside a pstack-mode run. The parent owns the playbook and the todo list; this delegate runs one scoped piece of one. It is never the runner of the mode itself.

The parent fills the three sections below and sends the brief as the `delegate_task` task text. Children cannot ask questions, so the brief must be self-sufficient.

## Goal

<one sentence, the outcome this delegate must produce, stated by the parent>

## Context

The parent pastes into the brief:

- absolute file paths this delegate may read or edit, plus the path of the pstack-mode skill directory
- the task or playbook step text this delegate executes, verbatim
- constraints: branch or git worktree path, do-not-touch list, definition of done

Rules this delegate follows:

- Read the pstack-mode SKILL.md first, and every principle leaf under `references/principles/` that the work applies. Name each principle that shaped a decision in the report, with the choice it changed.
- Work from the file pointers in the brief, not from re-dumped context.
- Never ask questions back. Report blockers as a `BLOCKED:` line naming what the parent must decide.

## Expected output

A report with evidence: what changed and why, files touched, commands run with their output, and the repro or check that proves the central claim. The parent reruns the repro. A "fixed" claim is unverified until then.
EOF

  cat > "$HM_REF/agents/comment-sicko-brief.md" <<'EOF'
# comment-sicko delegate brief (Hermes template)

What this delegate is for: a report-only comment purge review. It savors deletion and condemns workaround code. It touches comments and names refactor targets; it never writes application code.

The parent fills the three sections below and sends the brief as the `delegate_task` task text.

## Goal

<one sentence, the comment review this delegate must deliver, stated by the parent>

## Context

The parent pastes into the brief:

- absolute paths of the files to review, or the diff text against the base ref, with the base named
- constraints: scope boundary, and whether deletion is applied in place or reported only

Rules this delegate keeps:

- Narration, banners, commented-out corpses, and workaround sermons are meat. Kill them.
- The keep list is the only leash: legal or license headers; non-obvious behavior forced by an external dependency, platform, vendor, or protocol we cannot reshape (mark the exact symbol `MUST KILL` for the reshape that makes the behavior obvious); lint suppressions only when their rule is faulty, pedantic, or style-only; doc comments defining a public API contract; issue or RFC links explaining a constraint code cannot express.
- Doubt after reading nearby code is meat, with one exception. When a comment states a rule the code cannot prove, hunt the docs or source of whatever sets it. Confirmed for this code, it stays under the keep list. Refuted, it dies, and the kill cites the page or file. Unsettled or unreachable, it stays put as a `HOLD`, the one case where doubt is not meat.
- `eslint-disable`, `@ts-ignore`, and friends get their rule looked up. A rule that catches real bugs means kill the suppression and mark the guilty symbol `MUST KILL`.
- It invents nothing. Every flag names code inside the scope and tells the truth.

## Expected output

Report: files touched, deletion count, each dependency-rule kill with its citation, each `MUST KILL` flag with one line, each `HOLD` with the rule and where to verify it, and skips. The parent applies or dismisses every flag and owns the code.
EOF

  # --- smoke test instructions (tracked file; regenerate byte-identical) --------
  cat > "$OUT/SMOKE-TEST.md" <<'EOF'
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
EOF

  # --- summary ------------------------------------------------------------------
  pb_count="$(ls "$HM_REF/playbooks" | wc -l | tr -d ' ')"
  hprin_count="$(ls "$HM_REF/principles" | wc -l | tr -d ' ')"
  echo "hermes target: playbooks $pb_count, principles $hprin_count, SKILL.md $skill_chars chars"
  echo "hermes output: $OUT"
}

# =============================================================================
# Target 4: DeepSeek Harness bundle (dsh/, tracked root package.json)
# =============================================================================
build_dsh() {
  OUT="$SCRIPT_DIR/dsh"

  # --- clean rebuild -----------------------------------------------------------
  rm -rf "$OUT"
  mkdir -p "$OUT/lib" "$OUT/skills"

  # --- registered skills: full directory copies --------------------------------
  for s in $REGISTERED_DSH; do
    [ -d "$SRC_SKILLS/$s" ] || { echo "FATAL: registered skill missing in clone: $s"; exit 1; }
    cp -R "$SRC_SKILLS/$s" "$OUT/skills/$s"
    normalize "$OUT/skills/$s/SKILL.md"
  done

  # --- description guard: the dsh catalog caps descriptions at DSH_DESC_MAX ----
  dsh_max_desc=0
  dsh_max_desc_name=""
  for s in $REGISTERED_DSH; do
    f="$OUT/skills/$s/SKILL.md"
    d="$(awk '/^description:/{sub(/^description:[ ]*/,""); gsub(/^"|"$/,""); print; exit}' "$f")"
    dlen="$(printf '%s' "$d" | wc -c | tr -d ' ')"
    if [ "$dlen" -gt "$dsh_max_desc" ]; then dsh_max_desc="$dlen"; dsh_max_desc_name="$s"; fi
    [ "$dlen" -le "$DSH_DESC_MAX" ] || { echo "FATAL: dsh catalog description of $s is $dlen chars (limit $DSH_DESC_MAX); shorten the frontmatter"; exit 1; }
  done

  # --- reference tier under poteto-mode/references/ ----------------------------
  # setup-pstack lands here on purpose: not registered, still readable on demand.
  PM_REF="$OUT/skills/poteto-mode/references"
  PRIN="$PM_REF/principles"
  REFS="$PM_REF/skills"
  is_registered_target() { is_registered_dsh "$1"; }
  is_generated_target()  { is_generated_dsh "$1"; }
  copy_reference_tier

  # --- DSH runtime mapping, stamped with the port pin like the Hermes sheet ----
  cat > "$PM_REF/dsh-tools.md" <<'EOF'
# DSH runtime mapping

Build-time adaptation (sync.sh in this repository). pstack bodies are Claude Code native. In DeepSeek Harness, read this file once per session and map each name with the table below. Port version __VER__, pin __SHA__.

| Claude Code primitive | DSH |
|---|---|
| Task tool spawn (fresh child) | `subagent`. It is continuable and defaults to background with automatic settlement delivery; steer a running child with `send_message` and list children with `list_agents`. |
| Task tool spawn (fork) | `subagent_fork`, the fork backend: a fresh child seeded with the parent's settled context (it does not see the in-flight turn); continuable and backgrounded like `subagent`. |
| `subagent_type: poteto-agent` | No named subagent types. Prepend the brief to the task text: goal, full context (absolute file paths, the verbatim step, constraints), expected output. The child reads referenced files itself. |
| readonly spawn flag | Not a spawn parameter. Put "do not edit files" in the child's task text, then check `git status` after it returns. |
| spawn `run_in_background: true` | Omit. `subagent` already defaults to background and delivers the settlement; a background bash run reports through `job_output` and stops with `job_kill`. |
| TaskCreate / TodoWrite | `todo_write`. |
| AskUserQuestion | `ask_user_question` (by packaging convention the parent asks; children get full context up front). |
| Read / Grep / Glob | `read` / `grep` / `glob` (lowercase). `bash` is unchanged. |
| Transcript file reads (recall, ketchup, correct, reflect, automate-me) | Session transcripts live under the DSH home (`~/.dsh`). Use `session_search` when the session-query tools are loaded; otherwise skip with the policy below. |
| `environment: "cloud"` | Omit. For isolation, pass the child a git worktree path. |
| Model slugs (opus/fable/sonnet/haiku tiers) | Omit. This packaging passes no model or reasoning overrides; children inherit the session default. Per-child agentPreset is the operator's explicit configuration and is never written by this build. |
| Cursor Automations, Bugbot, Cursor cloud agents, /loop | Skip with the policy below. |
| Plugin rules file pstack-models.mdc | Not shipped. This build writes no model configuration (DEVIATIONS.md items 7 and 10). |

## Skip policy (verbatim)

When a step needs one, put one line in your reply, `Skipped: <step>. <reason>.`, then go on. Do not stop, ask, or retry.
EOF
  sed -e "s/__VER__/$VER/g" -e "s/__SHA__/$SHA/g" "$PM_REF/dsh-tools.md" > "$PM_REF/dsh-tools.md.norm.tmp" && mv "$PM_REF/dsh-tools.md.norm.tmp" "$PM_REF/dsh-tools.md"

  # --- declared adaptation note appended to the copied poteto-mode SKILL.md ----
  cat >> "$OUT/skills/poteto-mode/SKILL.md" <<'EOF'

<!-- pstack-dsh-adaptation: generated by sync.sh; regenerate, do not hand-edit -->

## DSH adaptation

This copy runs on DeepSeek Harness (the custom-pstack-dsh bundle).

- Tool names differ from Claude Code. Full mapping: `references/dsh-tools.md` beside this file.
- Leaf skills without their own DSH entry live here: principles at `references/principles/<name>.md`, other skills at `references/skills/<name>/SKILL.md` (paths relative to this file; read them with the read tool when this skill or a playbook names them).
- Model roles: this packaging passes no model or reasoning overrides, so children inherit the session default. Per-child agentPreset is the operator's explicit configuration and is never written by this build. Never edit model configuration without the operator asking. Do not claim panel diversity: panels are single-model unless the operator configures per-child models.
- Cursor-only steps: put one line in your reply, `Skipped: <step>. <reason>.`, then go on. Do not stop, ask, or retry.
EOF

  # --- generated skill: pstack-guide (DeepSeek Harness) -------------------------
  GUIDE_BODY="$OUT/skills/pstack-guide/SKILL.md"
  mkdir -p "$OUT/skills/pstack-guide"
  cat > "$GUIDE_BODY" <<'EOF'
---
name: pstack-guide
description: Index of the pstack skills available in this DeepSeek Harness bundle and when to invoke each. Use when unsure which pstack skill applies, when asked what pstack provides, or to find a pstack skill or principle by name.
---

# pstack skill guide (DeepSeek Harness)

pstack is Lauren Tan's rigorous engineering stack (MIT), shipped for DeepSeek Harness via the michael-denyer port. Two tiers: registered skills below are always visible to the model (invoke with /name or describe the need); reference leaves load only when read from disk.

## Routing rules

1. Non-trivial coding task: nothing to invoke by hand. poteto-mode owns the playbook and todo list and pulls principles as needed. For automatic routing on every non-trivial task, add the router line to your instruction file (~/.dsh/AGENTS.md): "For non-trivial coding tasks, load and follow the poteto-mode skill; skip Cursor-only steps with a one-line note."
2. Know the specific skill: invoke /name from the registered table.
3. Not sure: read the tables below; the descriptions are the port's own. Reference leaves are listed at the bottom with their on-disk paths.

## Registered skills

| Skill | Invoke | First line of its description |
|---|---|---|
EOF

  for s in pstack-guide $REGISTERED_DSH; do
    f="$OUT/skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    desc="$(awk '/^description:/{sub(/^description:[ ]*/,""); gsub(/^"|"$/,""); print; exit}' "$f")"
    first="$(printf '%s' "$desc" | cut -c1-160 | sed -e 's/\\//g' -e 's/|/\\|/g')"
    printf '| %s | /%s | %s |\n' "$s" "$s" "$first" >> "$GUIDE_BODY"
  done

  cat >> "$GUIDE_BODY" <<'EOF'

## Reference leaves (read on demand, no auto-trigger)

Principles live at `poteto-mode/references/principles/<name>.md`; other leaves at `poteto-mode/references/skills/<name>/SKILL.md` (paths relative to the poteto-mode skill directory). dsh discovers skills one level deep, so these nested leaves are not registered skills; that nesting is the two-tier design.

### Principles
EOF
  printf '%b' "$ref_principles" | sed '/^$/d' | awk '{printf "- %s\n", $0}' >> "$GUIDE_BODY"
  cat >> "$GUIDE_BODY" <<'EOF'

### Other skills
EOF
  printf '%b' "$ref_skills" | sed '/^$/d' | awk '{printf "- %s\n", $0}' >> "$GUIDE_BODY"
  cat >> "$GUIDE_BODY" <<EOF

## Not in this build

Cursor-team-kit extras (deslop, fix-ci, fix-merge-conflicts, get-pr-comments, make-pr-easy-to-review, what-did-i-get-done) and the thermos review pack (thermos, thermo-nuclear-review, thermo-nuclear-code-quality-review) are excluded by this repository's packaging decision (see the README, "What this packaging changes"). setup-pstack ships as a reference leaf, not a registered skill: its sheet paths are Claude and Codex specific, and this packaging writes no model configuration.

Source: port version $VER, pin $SHA. Regenerated by sync.sh in this repository; edit that script's tier lists and re-run to promote or demote skills.
EOF

  # --- bundle provider: serves skills/ through ctx.skills (no dependencies) ----
  cat > "$OUT/lib/index.mjs" <<'EOF'
/**
 * pstack skill provider for the custom-pstack-dsh DeepSeek Harness bundle.
 *
 * Modeled on monkeyin92/ds-pstack lib/skills.js (MIT), with the per-skill
 * resource base of pstack-ports/dsh-pstack. Generated by sync.sh; regenerate,
 * do not hand-edit. Installing this bundle is one step: the provider serves
 * the skills/ directory beside this module through ctx.skills, so nothing is
 * copied into ~/.dsh/skills.
 */

import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

/** Provider name registered on ctx.skills. */
const PROVIDER_NAME = 'pstack-dsh'

/** Origin bucket for bundle-served skills (skills.md SkillSource). */
const SOURCE = 'bundled'

/**
 * Bundled tier rank (skills.md local discovery table): the project roots
 * (100 to 300) and user roots (400 to 500) are lower and win duplicate
 * names, so a project's .dsh/skills copy outranks this bundle.
 */
const RANK = 600

/** One directory per skill, relative to this module. */
const SKILLS_DIR = fileURLToPath(new URL('../skills/', import.meta.url))

/** The kebab-case name grammar the registry enforces. */
const SKILL_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

/**
 * Parse the frontmatter subset these skills use: `key: value` scalars with
 * optional quotes. A full YAML parser would be a dependency for two fields,
 * and one unparsable skill must not break the catalog, so unknown shapes
 * yield empty fields and the skill is dropped, not thrown.
 */
function splitSkill(source) {
  if (!source.startsWith('---')) return { frontmatter: {}, body: source }
  const end = source.search(/\n---[ \t]*(?:\r?\n|$)/)
  if (end < 0) return { frontmatter: {}, body: source }
  const closing = /\n---[ \t]*(?:\r?\n|$)/.exec(source.slice(end))
  const body = source.slice(end + (closing?.[0].length ?? 4)).replace(/^\r?\n/, '')
  const frontmatter = {}
  for (const line of source.slice(3, end).split(/\r?\n/)) {
    const match = /^([A-Za-z][A-Za-z0-9_-]*):[ \t]*(.*)$/.exec(line)
    if (match === null) continue
    const raw = match[2].trim()
    // A block-scalar indicator is multi-line content this minimal parser does
    // not handle: leave the key unset rather than publish a literal '>' or '|'
    // as the value. An unset name falls back to the directory name and an
    // unset description drops the skill, which the registry would do anyway.
    if (raw === '' || raw[0] === '>' || raw[0] === '|') continue
    frontmatter[match[1]] = unquote(raw)
  }
  return { frontmatter, body }
}

function unquote(value) {
  const t = value.trim()
  if (t.length >= 2 && ((t[0] === '"' && t[t.length - 1] === '"') || (t[0] === "'" && t[t.length - 1] === "'"))) {
    return t.slice(1, -1)
  }
  return t
}

function parseBoolean(value) {
  if (typeof value !== 'string') return undefined
  const n = value.trim().toLowerCase()
  if (['true', 'yes', 'on', '1'].includes(n)) return true
  if (['false', 'no', 'off', '0'].includes(n)) return false
  return undefined
}

/**
 * Candidate for one skill directory, or undefined when unusable: the registry
 * drops a malformed name or empty description anyway, and dropping it here
 * keeps one bad file from failing the whole catalog observation. Omitted
 * frontmatter flags permit both invocation surfaces (registry default).
 */
function candidateOf(dir, source, path) {
  const { frontmatter } = splitSkill(source)
  const declared = typeof frontmatter.name === 'string' && frontmatter.name !== '' ? frontmatter.name : dir
  if (!SKILL_NAME.test(declared)) return undefined
  const description = typeof frontmatter.description === 'string' ? frontmatter.description.trim() : ''
  if (description === '') return undefined
  return {
    name: declared,
    description,
    invocation: {
      modelInvocable: parseBoolean(frontmatter['disable-model-invocation']) !== true,
      userInvocable: parseBoolean(frontmatter['user-invocable']) !== false,
    },
    source: SOURCE,
    provider: PROVIDER_NAME,
    resourceBase: { kind: 'directory', path: join(SKILLS_DIR, dir) },
    rank: RANK,
    locator: path,
  }
}

async function listSkills() {
  let entries
  try {
    entries = await readdir(SKILLS_DIR, { withFileTypes: true })
  } catch (error) {
    // A bundle installed without its skills directory is a packaging defect,
    // not a runtime condition: report it rather than serving an empty catalog.
    throw new Error(`pstack-dsh: cannot read skill directory ${SKILLS_DIR}: ${String(error?.message ?? error)}`)
  }
  const candidates = []
  for (const entry of entries) {
    if (!entry.isDirectory()) continue
    const path = join(SKILLS_DIR, entry.name, 'SKILL.md')
    let source
    try {
      source = await readFile(path, 'utf8')
    } catch {
      continue
    }
    const candidate = candidateOf(entry.name, source, path)
    if (candidate !== undefined) candidates.push(candidate)
  }
  return candidates
}

/** The skill provider registered on ctx.skills. */
const provider = {
  name: PROVIDER_NAME,
  async list() {
    return { candidates: await listSkills(), complete: true }
  },
  async get(candidate, options) {
    if (typeof candidate?.locator !== 'string') return undefined
    const source = await readFile(candidate.locator, { encoding: 'utf8', signal: options?.signal })
    const { body } = splitSkill(source)
    const { rank: _rank, locator: _locator, ...summary } = candidate
    return { ...summary, content: body }
  },
}

/** Cordis plugin name; the profile row id is set by cordis.patch.yml. */
export const name = 'pstack'

/** The skill registry is a hard dependency. */
export const inject = ['skills']

/** Register the bundled provider. */
export function apply(ctx) {
  ctx.skills.registerProvider(() => provider)
}
EOF

  # --- bundle patch: one insert row, resolved through the package manifest -----
  cat > "$OUT/cordis.patch.yml" <<'EOF'
# custom-pstack-dsh bundle patch. Generated by sync.sh; regenerate, do not hand-edit.
#
# Declared by package.json "dsh"."bundle"."patch"; applied when this package is
# listed in a profile's dsh.profile.bundles. The row mounts the pstack skill
# provider in lib/index.mjs, which serves this bundle's skills/ directory.
# The row name resolves through the package manifest (main / exports): the
# publish docs prescribe package-name resolution for bundle rows, so Node
# resolution finds the installed code.

- insert:
    - id: pstack
      name: custom-pstack-dsh
EOF

  # --- dsh/README.md ------------------------------------------------------------
  cat > "$OUT/README.md" <<'EOF'
# pstack bundle for DeepSeek Harness

This directory is a dsh plugin bundle: Lauren Tan's pstack skills, generated by sync.sh in this repository. The provider in `lib/index.mjs` serves the `skills/` tree through the harness skill registry. Do not hand-edit anything here; re-run `./sync.sh`.

## Two tiers, one discovery level

dsh discovers skills one level deep. The 14 top-level directories under `skills/` register as skills. Everything else nests under `skills/poteto-mode/references/` and is read on demand, so the nested leaves never enter the catalog. That nesting is the two-tier design, not an accident. Tool-name differences are mapped in `skills/poteto-mode/references/dsh-tools.md`.

## Install

From a git checkout (pin the ref; the publish docs advise a commit SHA pin so a later push cannot silently change what runs, a tag such as dsh-<version> also works):

    dsh plugin --profile <name> add github:dtembe/CustomPstack#dsh-<version>
    dsh plugin --profile <name> add github:dtembe/CustomPstack#<commit-sha>

Or from a local checkout:

    dsh plugin --profile <name> add /path/to/CustomPstack

The provider is plain ESM, so no build script runs and no build allowance is needed.

## Update and rollback

Update: `git pull`, re-run `./sync.sh`, then run the same `dsh plugin add` command again. Rollback: `dsh plugin --profile <name> remove custom-pstack-dsh`.

## Routing and models

Put the routing line in `~/.dsh/AGENTS.md`:

    For non-trivial coding tasks, load and follow the poteto-mode skill; skip Cursor-only steps with a one-line note.

This bundle passes no model or reasoning overrides. Children inherit the session default, and per-child agentPreset stays the operator's configuration. Never edit model configuration without the operator asking; panels are single-model unless the operator configures per-child models.

## Status

Developer-preview software on a developer-preview harness (dsh 0.2.x). The root package.json declares `engines.dsh: >=0.2.0 <0.3.0`, which dsh enforces at install and profile boot.
EOF

  # --- smoke test instructions (same fixture and shape as the Hermes one) -------
  cat > "$OUT/SMOKE-TEST.md" <<'EOF'
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
EOF

  # --- tracked root package.json: the bundle manifest dsh resolves --------------
  cat > "$SCRIPT_DIR/package.json" <<EOF
{
  "name": "custom-pstack-dsh",
  "version": "$VER",
  "private": true,
  "type": "module",
  "description": "pstack for DeepSeek Harness: Lauren Tan's rigorous agent-workflow skills via michael-denyer/pstack-claude $VER @ $SHA. Two-tier build served by a bundle skills provider.",
  "author": "Dan Tembe",
  "license": "MIT",
  "main": "./dsh/lib/index.mjs",
  "exports": {
    ".": "./dsh/lib/index.mjs",
    "./package.json": "./package.json"
  },
  "files": ["dsh", "README.md", "LICENSE", "NOTICE-skills.md", "DEVIATIONS.md"],
  "engines": {
    "dsh": ">=0.2.0 <0.3.0"
  },
  "dsh": {
    "bundle": {
      "patch": "./dsh/cordis.patch.yml"
    }
  }
}
EOF

  # --- summary ------------------------------------------------------------------
  dsh_count="$(ls "$OUT/skills" | wc -l | tr -d ' ')"
  dprin_count="$(ls "$PRIN" | wc -l | tr -d ' ')"
  dref_count="$(ls "$REFS" | wc -l | tr -d ' ')"
  echo "dsh target: skills $dsh_count (incl. pstack-guide), reference principles $dprin_count, reference skills $dref_count, max description $dsh_max_desc chars ($dsh_max_desc_name, limit $DSH_DESC_MAX)"
  echo "dsh output: $OUT"
}

# --- run every target, Zcode first (its root artifacts are the reference copy) --
build_zcode
build_cc
build_hermes
build_dsh
echo "build complete: pstack/ (Zcode), pstack-cc/ (Claude Code / Codex), hermes/ (Hermes router), dsh/ (DeepSeek Harness bundle)"
