#!/bin/bash
# pstack multi-harness plugin build.
# Regenerates every publish target from the michael-denyer/pstack-claude clone:
#   pstack/     Zcode plugin (registered tier + generated Zcode adaptation)
#   pstack-cc/  shared Claude Code / Codex plugin (port-native flavor)
#   hermes/     one Hermes router skill (pstack-mode)
#   .claude-plugin/marketplace.json and .agents/plugins/marketplace.json
#               root manifests for the shared pstack-cc tree
# The clone is located in this order: $PSTACK_PORT_DIR, a sibling of the seed
# root (../../repo-port-denyer, the local seed layout), ./repo-port-denyer
# (published repository layout), or a fresh shallow clone.
# Knobs below: EXCLUDED = never shipped by any target; REGISTERED / GENERATED =
# the Zcode tier; REGISTERED_CC / GENERATED_CC = the shared Claude Code / Codex
# tier. Every other pstack-proper skill ships as an on-demand reference under
# poteto-mode/references/ (Zcode and pstack-cc) or as a Hermes principle leaf.
# Edit the knobs, re-run this script, reinstall/update per harness.
#
# Rules implemented (PSTACK-DEV-PLAN.md section 4 and the CC/Hermes extension):
#   - Zcode: single-model panels declared, never faked
#   - pstack-cc: port text kept as-is (Claude Code and Codex take real
#     per-subagent models; the port carries the role defaults)
#   - Cursor-only steps skipped with a one-line note (verbatim policy)
#   - no model config changes
#   - user-invocable: false stripped from all copies (Claude-only field; Dan, 2026-11-13)
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

  # --- summary ------------------------------------------------------------------
  pb_count="$(ls "$HM_REF/playbooks" | wc -l | tr -d ' ')"
  hprin_count="$(ls "$HM_REF/principles" | wc -l | tr -d ' ')"
  echo "hermes target: playbooks $pb_count, principles $hprin_count, SKILL.md $skill_chars chars"
  echo "hermes output: $OUT"
}

# --- run every target, Zcode first (its root artifacts are the reference copy) --
build_zcode
build_cc
build_hermes
echo "build complete: pstack/ (Zcode), pstack-cc/ (Claude Code / Codex), hermes/ (Hermes router)"
