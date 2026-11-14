# DSH runtime mapping

Build-time adaptation (sync.sh in this repository). pstack bodies are Claude Code native. In DeepSeek Harness, read this file once per session and map each name with the table below. Port version 0.9.138, pin a12b047.

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
