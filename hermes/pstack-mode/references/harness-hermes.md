# pstack in Hermes

Build-time adaptation (sync.sh in this repository). pstack skill bodies are Claude Code native. In Hermes, read this file once per session and map each Cursor or Claude Code name with the table below. Port version 0.9.138, pin a12b047.

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
