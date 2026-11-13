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
