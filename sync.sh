#!/bin/bash
# pstack Zcode plugin build.
# Regenerates pstack/ (this directory) from the michael-denyer/pstack-claude
# clone. The clone is located in this order: $PSTACK_PORT_DIR, a sibling of the
# seed root (../../repo-port-denyer, the local seed layout), ./repo-port-denyer
# (published repository layout), or a fresh shallow clone.
# Knobs below: EXCLUDED = never shipped; REGISTERED = shipped as real Zcode skills;
# every other pstack-proper skill ships as an on-demand reference under
# poteto-mode/references/. Edit the knobs, re-run this script, reinstall/update.
#
# Rules implemented (PSTACK-DEV-PLAN.md section 4):
#   - single-model panels declared, never faked
#   - Cursor-only steps skipped with a one-line note (verbatim policy)
#   - no model config changes
#   - user-invocable: false stripped from all copies (Claude-only field; Dan, 2026-11-13)
set -euo pipefail

# Resolve locations relative to this script, so the same script runs from the
# seed (builds/zcode/) and from a published repository checkout. Env override
# wins. Missing port clone is fetched as a shallow clone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT_DIR="${PSTACK_PORT_DIR:-}"
if [ -z "$PORT_DIR" ]; then
  for candidate in "$SCRIPT_DIR/../../repo-port-denyer" "$SCRIPT_DIR/repo-port-denyer"; do
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
OUT="$SCRIPT_DIR/pstack"

EXCLUDED="deslop fix-ci fix-merge-conflicts get-pr-comments make-pr-easy-to-review what-did-i-get-done thermos thermo-nuclear-review thermo-nuclear-code-quality-review"
REGISTERED="poteto-mode unslop tdd arena swarm interrogate sharpen technical-writing no-comments babysit architect blast-radius show-me-your-work"
GENERATED="pstack-zcode pstack-guide"

VER="$(cat "$SRC/VERSION" 2>/dev/null || echo unknown)"
SHA="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"

is_excluded()   { case " $EXCLUDED " in   *" $1 "*) return 0;; *) return 1;; esac; }
is_registered() { case " $REGISTERED " in *" $1 "*) return 0;; *) return 1;; esac; }
is_generated()  { case " $GENERATED " in  *" $1 "*) return 0;; *) return 1;; esac; }
is_principle()  { case "$1" in principle-*) return 0;; *) return 1;; esac; }

# Strip the Claude-only field from a SKILL.md copy (macOS/BSD sed).
normalize() { sed -i '' -e '/^user-invocable:/d' "$1"; }

echo "pstack zcode build: source pin $SHA, version $VER"

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
mkdir -p "$PRIN" "$REFS"
ref_principles=""
ref_skills=""
for d in "$SRC_SKILLS"/*/; do
  n="$(basename "$d")"
  is_excluded "$n" && continue
  is_registered "$n" && continue
  is_generated "$n" && continue
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
| Model slugs (opus/fable/sonnet/haiku tiers) | Every role inherits the session model. Review panels (arena, interrogate) are single-model on Zcode; say so plainly, never claim diversity. Never edit model config without Dan asking. |
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

Every pstack model role inherits the session model. Review panels (arena, interrogate) are single-model on Zcode. Say so plainly; do not claim diversity. Never edit model configuration without Dan asking.

## Cursor-only skip policy (verbatim)

When a step needs one, put one line in your reply, \`Skipped: <step>. <reason>.\`, then go on. Do not stop, ask, or retry.

## Other Zcode differences

- setup-pstack: do not run it on Zcode. Model roles are fixed by the rules above.
- poteto-agent's cache-path fallback searches Claude Code plugin paths; on Zcode the parent must pass the absolute path to poteto-mode's SKILL.md.
- Reference-tier leaves (not registered as Zcode skills): principles at \`skills/poteto-mode/references/principles/<name>.md\`, other skills at \`skills/poteto-mode/references/skills/<name>/SKILL.md\`. Read on demand.
- Excluded from this build (cursor-team-kit and thermos extras, per PSTACK-DEV-PLAN section 5): __EXCLUDED__.
- Update path: git pull in repo-port-denyer, re-run sync.sh, then \`zcode plugins update pstack@pstack-local\`.
EOF
sed -i '' -e "s/__VER__/$VER/g" -e "s/__SHA__/$SHA/g" -e "s/__EXCLUDED__/$(echo $EXCLUDED | sed 's/ /, /g')/g" "$OUT/skills/pstack-zcode/SKILL.md"

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

Cursor-team-kit extras (deslop, fix-ci, fix-merge-conflicts, get-pr-comments, make-pr-easy-to-review, what-did-i-get-done) and the thermos review pack (thermos, thermo-nuclear-review, thermo-nuclear-code-quality-review) are excluded per PSTACK-DEV-PLAN section 5.

Source: port version $VER, pin $SHA. Regenerated by sync.sh in this repository; edit that script's tier lists and re-run to promote or demote skills.
EOF

# human-readable copy (frontmatter stripped via awk; BSD sed range gotcha avoided)
awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next} fm==1 && /^---[[:space:]]*$/ {fm=2; next} fm!=1 {print}' "$GUIDE_BODY" > "$SCRIPT_DIR/SKILL-GUIDE.md.tmp"
{ echo "<!-- Generated by sync.sh on $(date +%Y-%m-%d). Do not hand-edit; re-run sync.sh. -->"; echo; cat "$SCRIPT_DIR/SKILL-GUIDE.md.tmp"; } > "$SCRIPT_DIR/SKILL-GUIDE.md" && rm "$SCRIPT_DIR/SKILL-GUIDE.md.tmp"

# --- agents (verbatim; verified no model frontmatter) -------------------------
cp "$SRC/plugins/pstack/agents/poteto-agent.md" "$OUT/agents/"
cp "$SRC/plugins/pstack/agents/comment-sicko.md" "$OUT/agents/"

# --- licenses / provenance ----------------------------------------------------
cp "$SRC/plugins/pstack/LICENSE" "$OUT/LICENSE" 2>/dev/null || cp "$SRC/LICENSE" "$OUT/LICENSE"
cp "$SRC/NOTICE-skills.md" "$OUT/NOTICE-skills.md"

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
echo "registered skills: $reg_count (incl. pstack-zcode, pstack-guide)"
echo "reference principles: $prin_count"
echo "reference skills: $ref_count"
echo "excluded: $EXCLUDED"
echo "source pin: $SHA  version: $VER"
echo "output: $OUT"
