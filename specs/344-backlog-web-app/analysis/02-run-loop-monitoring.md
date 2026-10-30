# 344 analysis 02 - monitoring and controlling the backlog run loop

Scope: the run loop (`bin/backlog-loop.sh`, `tools/backlog/loop.py`), one implementation run
(`/tandem-backlog-implement`), traces (`tools/backlog/traces.py`, `.agent-traces/`) and run
history (`backlog/RUNS.md`, `index.jsonl`, `meta.json`). Backlog data operations and the tech
stack are covered by other analyses.

Measured on 2026-10-30, `Pavel-PC-5950X`: Windows 11, claude 2.1.314 (native
`C:\Users\pavel\.local\bin\claude.EXE`), Node v24.22.1, Python 3.15.1. All experiments ran
against scratch repositories built from `tools/backlog/fixtures/valid` with
`tools/backlog/fixtures/fake_claude.py` (as `test_loop.py` does). Nothing in the repository
was changed. The scripts are listed in the appendix.

## 0. What exists on this machine now (measured)

| Thing | State | Evidence |
|---|---|---|
| `.git/tandem-backlog-loop/` (loop control and state) | **absent** | `ls .git/tandem-backlog-loop` → no such directory; `git rev-parse --git-common-dir` = `.git` |
| `.agent-traces/` in the repository | **absent**, though ignored (`.gitignore:37-38`) | `ls .agent-traces` → no such directory |
| run lock `.git/tandem-backlog-run.lock` | free | `bin/backlog-loop.sh status --json` → `"lock": null, "lock_text": "free"` |
| `status --json` | `{"loop": null, "live": false, "run": null, "triage": null, "paused": false, "stop": false, "lock": null, "lock_text": "free", "trace": null, "traces_bytes": 0}`, exit 0 | run on 2026-10-30 |
| history of the traces | 547 MB, 142 run folders (95 item runs, 47 triages) existed on 2026-10-25 after the one-time move | `specs/342-backlog-agent-traces/fix-log.md:66-72` |
| claude's own transcripts of loop sessions | gone (only 4 sessions in `~/.claude/projects/D--Projects-tandemcommander/`, none of them loop runs) | `ls` |
| other clones | none; `E:\` exists but has no `Projects` folder | `ls /e/Projects` |
| traces of the same format elsewhere | `D:\Projects\2026_energy_encyclopedia_ai_audio_chatbot_2\.agent-traces\` (1 run, `index.jsonl` 1 line); `D:\Projects\2026_hscr_ai_chatbot\.agent-traces\` (empty) | `find /d -maxdepth 4 -name .agent-traces` |
| `backlog/RUNS.md` | 109 rows (2026-10-18 … 2026-10-24): closed 90, blocked 7, not-reproduced 7, split 5 | `grep -c '^| 20' backlog/RUNS.md` |

So the web app must start from **no loop state and no traces at all**: every reader must treat a
missing `.git/tandem-backlog-loop/`, a missing `.agent-traces/` and a missing `index.jsonl` as the
normal empty state. Until new runs happen, `RUNS.md` (and git history) is the only run history.
The trace format below was inspected on the one real trace that exists (sibling project, same
contract 342, claude 2.1.310): `20261026-101351-claude-readme-neuvadi-backlog-a-skripty-bin`
(`trace.jsonl` 281 lines / 765 kB, `stderr.log`, `meta.json`, one index line). Its `meta.json`
has one extra key (`permissions`) and a UTC `started` (`…Z`) - that project's own implementation;
Tandem's `traces.iso_local` writes local time with offset (`traces.py:56-60`). Parse both.

Finding for the Inbox (not in scope here): `.claude/skills/tandem-backlog-implement/SKILL.md:334`
and `:342` hard-code `E:\Projects\tandemcommander` in the reviewer prompt, but the repository is
`D:\Projects\tandemcommander` and `E:\Projects` does not exist on this machine.

## 1. Every observable state

### 1.1 Sources and who writes them

| Source | Path | Writer | Written how | Reader notes |
|---|---|---|---|---|
| loop record | `.git/tandem-backlog-loop/loop.json` | the loop | `save_json` → `backlog.write_text` = temp file + `os.replace` (`loop.py:145-154`, `backlog.py:172-185`), retried 100 x 50 ms on `PermissionError`; rewritten **every tick (1 s)** while waiting or watching (`loop.py:613`, `:884`); removed when the loop ends (`loop.py:554-558`) | heartbeat field `updated` |
| run record | `.git/tandem-backlog-loop/run.json` | the loop | same; removed when the run finished or never took its item (`loop.py:638-642`) | survives the loop |
| triage record | `.git/tandem-backlog-loop/triage.json` | the loop | only while an auto-triage claude runs (`loop.py:1228`, `:1234`) | |
| pause / stop flags | `.git/tandem-backlog-loop/pause`, `stop` | `pause` / `stop` commands | existence only; content = a timestamp (`loop.py:1530`, `:1568`) | |
| import marker | `.git/tandem-backlog-loop/imported.json` | the loop, once | `loop.py:1346` | irrelevant for the app |
| run lock | `.git/tandem-backlog-run.lock` | the runs (`bin/backlog.sh lock acquire/update/release`) | `acquire`: `O_CREAT|O_EXCL` (`backlog.py:1675-1680`); `update`: `write_text` = `os.replace`, **no retry** (`backlog.py:1690-1696`); `release`: unlink (`backlog.py:1703`) | 4 lines `started/slug/branch/host` (`backlog.py:1161-1172`); **no pid, no session** |
| run folder | `.agent-traces/<YYYYMMDD-HHMMSS>-claude-<slug|triage>[-N]/` | the loop creates it (`traces.py:71-84`) | `mkdir` is the claim | |
| trace | `<run folder>/trace.jsonl` | claude (its stdout handle **is** the file, `loop.py:818-824`) + one separator line per attempt by the loop | append only, never replaced | live source |
| stderr | `<run folder>/stderr.log` | claude + one header per attempt (`traces.py:120-123`) | append only | lost-session text, crash text |
| run meta | `<run folder>/meta.json` | the loop | atomic replace (`traces.py:138-163`, 40 retries, then the error is only printed, `loop.py:726-729`) | written at start, at each attempt end, at the end |
| index | `.agent-traces/index.jsonl` | the loop, one line when a run ends | one `write` per line (`traces.py:166-172`) | history |
| journal | `backlog/RUNS.md` | the runs (`BL run-log`, `backlog.py:1640-1660`, `write_text`, no retry) | written on the feature branch, reaches `main` by the fast-forward | outcome source of truth |

`bin/backlog-loop.sh status --json` (`loop.py:1451-1468`) bundles `loop`, `live`, `run`, `triage`,
`paused`, `stop`, `lock`, `lock_text`, `trace`, `traces_bytes`. `live` needs the process creation
time (`process_ident`, `loop.py:174-210`, Win32 `GetProcessTimes` via ctypes) - Node has no
built-in API for it. `traces_bytes` walks the whole `.agent-traces/` tree (`traces.py:282-300`;
547 MB / 142 folders before) - fine every few seconds, not every 100 ms.

`loop.json` keys (`loop.py:530-531`, `565-573`): `pid`, `ident` (creation FILETIME as int), `host`,
`started`, `state`, `detail`, `until` (local `YYYY-MM-DD HH:MM:SS` or null), `ctrl_c_safe`,
`since`, `updated`, `slug`, `session`, `trace`, `counts` (`closed/blocked/not-reproduced/split/
nothing-to-do`), `items`, `blocked_streak`, `usage` (the last `rate_limit_info`), `auto_triage`,
`triages`.

`run.json` keys (`loop.py:620-626` + later): `slug`, `session`, `started` (local stamp),
`started_epoch`, `kind`, `trace`, `log`, `err`, `rows_before`, `attempts` (= error count!),
`stalls`, `resumes`, `limits`, `nudges`, `lock_started`, `phase`, `wait_until` (**epoch float**,
unlike `loop.json.until` which is a string), `why`, `child_pid`, `child_ident`, `trace_attempts`,
`next_reason`, `indexed`, `base` (HEAD at the start), `offset`, `err_offset`, transient
`exit_code`, `idle`.

### 1.2 Loop states

`loop.json.state` (contract `specs/247-backlog-run-loop/contracts/loop-cli.md:149-151`):

| State | Meaning | Source |
|---|---|---|
| `starting` | registered, before the first cycle | `loop.py:549` |
| `running` | an item's claude runs (also: waiting for a claude a previous loop left, `ctrl_c_safe: true`) | `loop.py:839`, `:1075` |
| `triage` | the auto-triage claude runs | `loop.py:1207` |
| `waiting` | precheck failed: lock held / not on `main` / tree dirty / `check` findings / `BACKLOG.md` malformed; or the lock held by another run while a pending run waits | `loop.py:1121-1146`, `:1105` |
| `idle` | nothing eligible in *Next* | `loop.py:1148-1149` |
| `paused` | pause flag set, between runs | `loop.py:1357` |
| `limit` | waiting for a usage-limit reset (`until` set) | `loop.py:1053`, `:1085-1088`, `:1253` |
| `backoff` | waiting after an error (`until` set) | `loop.py:1062`, `:1088`, `:1265` |

Derived states the web app should show (all measurable without new loop code):

| Shown state | Rule |
|---|---|
| **not running** | `loop.json` missing |
| **dead loop (ended without cleanup)** | `loop.json` present but `live == false` (status), or `updated` older than ~10 s (heartbeat, `loop.py:613`, `:884`). Measured: after `taskkill /T /F` of the loop, `loop.json` stays with `state: running` and `live: false` (appendix, scenario K) |
| **pause pending** | `pause` flag exists and `state` in `running`/`triage` (`loop.py:1534-1537`) |
| **stop pending** | `stop` flag exists, loop live, `state` in `running`/`triage` (`loop.py:1569-1571`) |
| **pause set, no loop** | `pause` flag, no live loop: the next start begins paused (`loop.py:1532-1533`) |
| **waiting and why** | `state` `waiting`/`idle` + `detail` (the reason in words, e.g. `waiting: the working tree is on '344-…', not on main`) |
| **usage limit inside claude** | `state` `running`, `detail` ends `; claude waits for the usage limit until HH:MM` (`loop.py:876-878`), `loop.json.usage.status == "rejected"` |
| **usage limit between attempts** | `state` `limit`, `until`; `run.json.phase == "waiting"`, `why == "a usage limit"` |
| **interrupted run** | `run.json` exists and the loop is not live; `phase` tells how: `running`/`new` (loop and claude killed together, no handler), `killed` (Ctrl+Break handler ran), `waiting` (limit/backoff/stall/idle, continues after `wait_until`), `failed`/`lost` (needs a person: `status` prints the *todo* commands, `loop.py:1496-1503`) |
| **orphan claude** | `run.json.child_pid` alive although the loop is dead (`loop.py:1504-1505`); also `triage.json` pid alive (`loop.py:1514-1516`). Measured: this is exactly what Node leaves behind when it kills its loop child (section 2.4) |
| **run outside the loop** | lock held, no `run.json`, no live loop: a manual `/tandem-backlog-implement` (no trace in `.agent-traces/`) |
| **Ctrl+C safety** | `loop.json.ctrl_c_safe` (`loop.py:1518-1523`) |

### 1.3 The current item and its phase in the Spec Kit flow

Current item: `loop.json.slug`, `run.json.slug`, the lock's `slug`; the feature branch appears in
the lock only after SKILL.md step 4.5 (`BL lock update`, `SKILL.md:242-247`), before that `-`.

The phases of one run (`SKILL.md`): 1 preconditions → 2 select + `lock acquire` → 3 measure
(`BL verify`) → 4 specify (branch + `specs/<BRANCH>/`, `BL start`, commit `[NNN] start`) →
5 clarify, plan, tasks, analyze, implement → 6 verify (encoding guard, build, saltests, probes) →
7 independent review (Agent, up to three rounds) → 8 close (`BL remove`, FEATURE-HISTORY,
CHANGELOG, closing report, `BL run-log`, commit) → 9 fast-forward `main` (or merge `main` into the
branch) → `lock release` → 11 final message. Stop path: step 10.

How reliably each source tells the phase (measured on the real trace and on run 341's commits):

| Source | What it gives | Reliability |
|---|---|---|
| **trace: `Skill` tool_use in the main thread** (`parent_tool_use_id == null`, `name == "Skill"`, `input.skill`) | measured, in order: `speckit-specify` 09:14:47, `speckit-git-feature` 09:14:51, `speckit-clarify` 09:15:52, `speckit-plan` 09:16:26, `speckit-tasks` 09:17:06, `speckit-analyze` 09:17:25, `speckit-implement` 09:17:45 | **high** for 4-5; one invocation per phase |
| **trace: `Agent` tool_use** | the review (step 7); `system/task_started` … `task_notification`/`task_updated` give its life; `tool_progress` heartbeats every 30 s (`elapsed_time_seconds`) | high; count = review round |
| **trace: `Bash` tool_use `input.command`** | `bin/backlog.sh lock acquire` (step 2), `verify` (3), `start` (4.5), `run-log` (8.8), `git merge --ff-only` (9), `git merge main --no-commit` (9, merge path), `block` (10), `lock release` (end) | high: the skill prescribes these exact commands |
| **trace: `PowerShell` tool_use** | `build.cmd` (6), `saltests.exe` (6), `run_on_hidden_desktop.ps1` (a **GUI probe is running** - matters for hard stop, section 5) | high |
| files in `specs/<BRANCH>/` (working tree) | `spec.md` (4), `plan.md`/`research.md` (5), `tasks.md` (5), `fix-log.md` (4.5 onwards), `closing-report.md` (8) | medium: they exist only while the branch is checked out; a stop or the fast-forward switches the tree; reading must tolerate ENOENT |
| commits `git log <base>..<branch>` | measured for 341: `[Spec Kit] Add specification` → `[341] start` → `[Spec Kit] Add implementation plan` → `[Spec Kit] Add tasks` → `[Spec Kit] Implementation progress` → `[341] review 1/2/3 …` → `[341] <user-visible change>` → `[341] merge main` (`.specify/extensions/git/git-config.yml` enables after_specify/clarify/plan/tasks/implement commits) | medium: lagging (a commit only at the end of a phase) and the `[Spec Kit]` commits are **not** in `meta.commits` (`traces.py:244-249` matches only `[NNN]` and `backlog: <slug>`) |
| `RUNS.md` row | the end (outcome) | definitive, but only at the end |

Recommendation: derive the phase from the trace (whole file, all attempts - a continued
attempt does not re-invoke the skills already done), as a monotonic state machine keyed on
Skill / Agent / the prescribed Bash commands; show the files and commits as a cross-check. After
a `--resume` the phase is the last one seen in earlier attempts until a new marker appears.

### 1.4 Progress, time, cost, messages, tool calls, files, commits, errors

| Observable | How | Notes |
|---|---|---|
| progress estimate | `specs/<BRANCH>/tasks.md`: count `^- \[[xX]\]` vs `^- \[ \]` (341: 24 / 0) | only during implement; the skill marks `[X]` as it goes (`SKILL.md:292`); tasks reverted later stay `[X]` with a note |
| elapsed | run: `run.json.started_epoch` / `meta.started`; attempt: separator `started`; state: `loop.json.since` | wall time includes limit waits between attempts |
| tokens / cost | the `result` event: `total_cost_usd`, `modelUsage.<model>.{inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens, costUSD, contextWindow}`, `model_usage_since_last_result`, `num_turns`, `duration_ms`, `duration_api_ms`, `subagent_stats` | **`meta.attempts[].usage` is `result.usage`, which excludes subagents** (measured: `cache_read_input_tokens` 6,874,601 vs `modelUsage` 7,509,880) and has no cost - use `modelUsage` / `total_cost_usd` |
| live token estimate | `assistant.message.usage` per API message; `system/thinking_tokens` (`estimated_tokens`) | **dedupe by `message.id`**: measured 106 assistant events but 62 distinct ids - one event per content block, each repeating the message's usage |
| several results per process | `system/init` repeats at every turn (342 research R6: 7 times in run 341) and a `result` ends each turn (`result_index`) | "a result arrived" ≠ "the run ended"; cost of an attempt = its last result; cost of a run = sum over attempts |
| last assistant message | last main-thread `assistant` content block of type `text` | `thinking` blocks carry an empty `thinking` string (signature only) - nothing to show |
| current tool call | last main-thread `tool_use` without a matching `tool_result` (`user` event, `tool_use_id`) | long calls: `tool_progress` heartbeats only for some tools (Agent measured); a 20-minute build shows nothing until its result |
| background tasks | `system/task_started` (`task_type`, `is_backgrounded`, `description`), `task_progress` (`last_tool_name`, `usage`), `task_notification` (`status`), `task_updated` (`patch.status`), `system/background_tasks_changed` (the loop's idle watchdog, `loop.py:390-395`) | reviewer liveness |
| subagent activity | events with `parent_tool_use_id` set, plus `agent_id`, `subagent_type`, `task_description` | group under the Agent call |
| usage windows | `rate_limit_event.rate_limit_info`: `status`, `resetsAt`, `rateLimitType`, `unifiedWindows.five_hour/seven_day.{utilization, resetsAt}`, `overageStatus` (measured: 5 events, utilization 0.17 → 0.21); `loop.json.usage` = the last one | |
| files changed | main-thread `Write`/`Edit` `input.file_path` (measured: 6 + 6) - no git needed; or `git diff --name-status <base> <branch>` (tree-to-tree, no locks) | `run.json.base` = HEAD at the start (`loop.py:625`) |
| commits | `git log --format=%h%x00%s <base>..<branch>`; at the end `meta.commits` | read-only, takes no lock |
| errors | `result.is_error`, `api_error_status`, `terminal_reason`, `permission_denials`; `stderr.log` (lost session `No conversation found`, `loop.py:108`); `run.json.why`; `meta.attempts[].ending/error_kind/exit_code`; `loop.json.detail` in `backoff` | |
| timestamps | `assistant` and `user` events carry `timestamp` (UTC ISO); `system/*`, `result`, `rate_limit_event`, `tool_progress` **do not** | replay timing: interpolate; live: use the reader's receive time |
| model / version | first `system/init` `.model`, `.claude_code_version`; `meta.model`, `meta.harness_version` | |
| todo list | **none**: the init tool list of claude 2.1.310 has no TodoWrite / TaskCreate (only `Task`, `TaskStop`) | progress only from `tasks.md` |

Event types measured in the real trace (281 lines): `assistant` 96 (+10 of a subagent),
`system/thinking_tokens` 75, `user` 64 (+11 subagent), `system/task_progress` 10,
`rate_limit_event` 5, `system/task_started` 2, `system/task_notification` 2, `tool_progress` 2
(subagent), `backlog_loop.attempt` 1, `system/init` 1, `system/task_updated` 1, `result/success` 1.
Content blocks: `tool_use` 67, `tool_result` 67, `thinking` 25, `text` 14. No partial-message
events (the loop does not pass `--include-partial-messages`, `loop.py:811-812`): text arrives as
whole blocks. The loop's own watchdog also reads `command_lifecycle` (`wakeup_source:
loop_wakeup`) and `ScheduleWakeup` tool_use (`loop.py:396-412`) - they appear when a run waits on
a reviewer.

## 2. Every control action

### 2.1 What exists

| Action | Command | Effect | Code |
|---|---|---|---|
| start | `bin/backlog-loop.sh start [opts]` = `exec python -u tools/backlog/loop.py start` | foreground loop; refused (exit 1) while another loop lives; registers `loop.json` with `O_EXCL`; removes a stale `stop` flag | `bin/backlog-loop.sh:64-65`, `loop.py:528-552` |
| `--max-items N` | end (0) after N finished runs (`nothing-to-do` does not count) | checked after the auto-triage | `loop.py:975-976`, `:1369-1371` |
| `--max-blocked N` (3) | stop (1) after N `blocked` in a row | | `loop.py:978-981` |
| `--poll S` (60) | re-check interval while waiting | | `loop.py:601` |
| `--model M` | passed to `claude --model` | also triage | `loop.py:813-814`, `:1210-1211` |
| `--until-idle` | end (0) when nothing is eligible | | `loop.py:1373-1375` |
| `--forget-run` | drop `run.json` first (indexes its trace once) | **the lock stays**; only after the maintainer cleaned up | `loop.py:1299-1307` |
| `--auto-triage` | `claude -p '/tandem-backlog auto-triage --commit'` before a run when the Inbox has items the last triage did not see | commits on `main` itself | `loop.py:1183-1289` |
| `--root DIR` | another repository | | `loop.py:1589`, `:1648` |
| hidden (tests) | `--claude-cmd`, `--backoff`, `--limit-margin`, `--limit-unknown-wait`, `--tick`, `--deadline` | never expose in the UI | `loop.py:1611-1616` |
| pause | `pause` | flag; the item finishes, then the loop waits; persists; works without a loop | `loop.py:1527-1545` |
| resume | `resume` | clears pause **and** a pending stop | `loop.py:1548-1559` |
| stop | `stop` | flag only while a loop lives; the item finishes, then exit 0 | `loop.py:1562-1574` |
| status | `status [--json]` | read-only | `loop.py:1451-1524` |
| hard stop | Ctrl+C / Ctrl+Break in the loop's console → `hard_stop` | kills claude's tree (`taskkill /T /F`), `run.json` phase `killed`, lock kept, exit 130 | `loop.py:1383-1426`, `:1443-1447` |

Not existing: **a single item by slug** (the loop always takes `backlog.next_eligible`,
`loop.py:1147`; the skill itself accepts a slug, `SKILL.md:118-119`), a hard stop from another
window, a persistent log of the loop's window lines (`say()` prints to stdout only, `loop.py:129-130`),
a record of why/how the last loop ended (`loop.json` is deleted, `loop.py:554-558`).

### 2.2 Hard stop on Windows - measured

All measured with the real `loop.py` and the fake claude holding the lock (`hang`):

| Scenario | Result |
|---|---|
| **B** Ctrl+Break (`os.kill(pid, CTRL_BREAK_EVENT)`) to a loop started with `CREATE_NEW_PROCESS_GROUP` | exit 130, `HARD STOP: claude was killed …` printed, fake claude dead, `run.json` phase `killed`, `why` "a hard stop (Ctrl+C) killed the process", lock kept, `meta.phase: killed`, no index line - the clean path |
| **K** `taskkill /PID <loop> /T /F` (what a Node backend can do) | 0.22 s, loop exit 1, fake claude dead (it is in the tree: `CREATE_NEW_PROCESS_GROUP` does not change the parent link), **nothing printed**, `loop.json` left behind (`state: running`, `live: false`), `run.json` phase `running`, `meta.phase: running`, lock kept. The next `start --until-idle` said "the run … was interrupted (the loop and claude ended while it ran …); it is continued in the same session", wrote separator 2 `continue / killed`, and closed the item; one index line - the documented Git Bash path (contract `loop-cli.md:124-128`, 247 review M2) |
| **C** `stop`, then `taskkill /T /F` of claude only (`run.json.child_pid`) | the loop judged it an **error**: "the run ended with an error (no result)", `run.json` phase `waiting`, `why` "an error: no result", `next_reason: error`, `attempts` (error counter) +1 toward the 5-error stop, then ended because of the stop flag - **misclassified; never do this** |
| Node `child.kill('SIGINT' / 'SIGBREAK' / 'SIGTERM')` on a Python child | always `TerminateProcess`: the Python handler never ran, and **the grandchild (claude stand-in) survived** |
| Python relay: a wrapper started by Node starts the target in a new group and sends `CTRL_BREAK_EVENT` | works when the target's stdin is `DEVNULL` (handler ran, exit 130) - also when Node has no console; with the wrapper's stdin pipe inherited, the target never got past start-up (no output at all, exit `0xC000013A` after the break) |

Lock and records after a hard stop: the lock always stays (by design: the item keeps it, the
next start continues the session, `SKILL.md:70-85`). Hard stop during a GUI probe leaves the
product's registry key modified until the continued run restores `%TEMP%\tcNNN_backup.reg`
(stop-rules §2.8, `loop.py:1115`, `:1416`).

`taskkill /T` walks parent-child links at the moment it runs: probes started by
`tools/run_on_hidden_desktop.ps1` are children (`CreateProcessW`, line 91) and die with the tree;
processes that detach themselves (MSBuild node reuse) survive by design.

### 2.3 What happens when the web app dies - measured

A Node host spawned `python child.py`, which started a grandchild in its own group (exactly how
`loop.py` starts claude); then the host was killed with `taskkill /F` (no `/T`):

| Spawn | Loop's console | claude's console | After Node died |
|---|---|---|---|
| plain `spawn(…, {windowsHide: true})` | no window | no window | **loop killed, claude alive** (libuv puts children in a kill-on-close job with silent breakaway, so grandchildren escape) |
| `detached: true` (+ `unref`) | none (`DETACHED_PROCESS`) | **a new visible console window** | loop alive, claude alive |

So hosting the loop as a plain child means: closing or crashing the web app kills the loop
without its handler and leaves claude working alone - recoverable (the next start waits for that
claude, `loop.py:1072-1081`), but no one is watching. Hosting it detached pops up a console window
for every claude (the loop does not pass `CREATE_NO_WINDOW`, `loop.py:816`).

A further consequence of a plain child sharing the server's console: a Ctrl+C typed into the
server's terminal reaches the loop too (Windows delivers it to every process of the console's
group 0; the loop handles SIGINT as a hard stop, `loop.py:1445`) - derived from the console
semantics and the contract (`loop-cli.md:121-128`), not measured.

### 2.4 Recommendation: drive the loop, do not host it

The web app should **drive the existing loop through its CLI and files, and never own the loop
process**:

1. **Start**: launch `bin/backlog-loop.sh start <options>` in **its own new terminal window**,
   detached from the server (e.g. `cmd /c start "Backlog loop" <git-bash or wt> …`). The loop
   then behaves exactly as when the maintainer starts it by hand: it has a console, Ctrl+C in
   that window keeps its tested meaning, the window shows the loop's lines, and closing the web
   app changes nothing. Before starting, read `status --json`: a live loop → show it instead (the
   loop would refuse anyway, `loop.py:532-540`). Expose `--max-items`, `--max-blocked`, `--poll`,
   `--model`, `--until-idle`, `--auto-triage`; `--forget-run` only next to the *todo* text of a
   `failed`/`lost` run, with confirmation. Prefer calling `python -u tools/backlog/loop.py` (what
   the wrapper does) over `bash`: `bash` on PATH can be WSL's (`test_loop.py:47-57`).
2. **Pause / resume / stop**: run `python tools/backlog/loop.py pause|resume|stop --root <repo>`
   (do not create or delete the flag files yourself - one source of truth, and `stop` sets nothing
   without a live loop). Show their output text.
3. **Status**: read `loop.json` / `run.json` / `triage.json` / flags directly at ~1 Hz (cheap,
   heartbeat via `updated`), and run `status --json` every few seconds for `live` (process
   identity) and `traces_bytes`.
4. **Hard stop**: today the only external way that keeps the loop's semantics is
   `taskkill /PID <loop pid> /T /F` after checking the pid is still the loop (`status --json`
   `live == true`, same `pid`), which is scenario K: claude dies, the run is continued at the next
   start with reason `killed`. Never kill claude alone (scenario C). Before it, warn when a GUI
   probe or an auto-triage is running (a killed triage leaves uncommitted changes in `backlog/`;
   the next start waits for a clean tree, `loop.py:1397-1399`).
5. **Loops started outside the app**: identical - everything the app reads is in files; only the
   window lines are missing (they never were persisted).

Small loop extensions that would make this clean (for the plan; all backward compatible):

| Extension | Why |
|---|---|
| `bin/backlog-loop.sh kill` → a `kill` flag the loop checks in `wait()`/`watch()` each tick and handles like Ctrl+Break (`hard_stop`, phase `killed`, the messages, exit 130) | a hard stop with the handler's record, from any process, no console tricks, no `taskkill` of Python |
| `say()` also appends to `.git/tandem-backlog-loop/loop.log` (one write per line) | the loop's narrative ("item X: closed", "auto-triage: 3 placed") for loops started anywhere |
| `last.json` written when the loop ends (exit code, reason, counts, ended) | today the app cannot tell why a loop ended |
| `start --item SLUG` (eligibility by `backlog next --slug`, implies one item) | running a single named item through the loop (trace, continuation, verdict); today the only way is `claude -p '/tandem-backlog-implement <slug>'` outside the loop - no trace, no continuation |
| `CREATE_NO_WINDOW` for claude when the loop has no console | only if hosting detached is ever wanted |

If hosting is chosen anyway: spawn a small Python relay (stdin pipe from Node) that starts
`loop.py start` with `CREATE_NEW_PROCESS_GROUP`, **stdin `DEVNULL`**, stdout to a log file, and
turns a "break" line into `CTRL_BREAK_EVENT` (measured to work, section 2.2). The relay dies with
Node (plain spawn), the loop then dies without its handler and claude keeps working - accept that,
or spawn the relay detached and give the loop `CREATE_NO_WINDOW` for claude.

## 3. Live streaming

### 3.1 Finding the current run

- `loop.json.trace` (item or triage, `loop.py:570`) and `run.json.trace` name the folder; the
  folder name is `<YYYYMMDD-HHMMSS>-claude-<slug|triage>[-N]` (`traces.py:71-84`).
- A new run = a new value of `loop.json.trace` (or a new folder in `.agent-traces/`; measured:
  `fs.watch` on a directory reports `rename` for new names and `change` for appends). Polling
  `loop.json` at 1 Hz is enough and simpler.
- A new attempt of the same run = a new `{"type":"backlog_loop.attempt", "attempt": n, "kind":
  "start|continue", "reason": "-|usage-limit|error|stall|idle|killed", "started", "session_id"}`
  line in the **same** `trace.jsonl` (`traces.py:112-117`; measured in scenario K: attempts
  `(1, start, -)`, `(2, continue, killed)`). The session id stays the same across attempts.
- The run ended = `run.json` gone / `meta.json.ended` set / a new `index.jsonl` line - **not** a
  `result` event (one per turn, several per process).

### 3.2 Tailing `trace.jsonl` robustly

- Keep a byte offset per file; on each poll (or `fs.watch` change) read from the offset to EOF,
  split on `\n`, keep the trailing incomplete fragment for the next read (exactly `read_lines`,
  `loop.py:359-370`). Decode UTF-8 only on whole lines (a multi-byte character can be split
  between reads).
- A line that does not parse is skipped: a claude killed mid-write leaves a partial line, which
  the loop terminates with `\n` before the next separator (`traces.py:98-109`, `loop.py:673-674`).
- `trace.jsonl` is never replaced or truncated by the loop. If its size drops below the offset (the
  folder was deleted by hand and recreated, `loop.py:817`), restart from 0.
- `meta.json` and the JSON state files are replaced atomically: read them whole, parse, and on a
  parse or permission error keep the previous value and retry on the next poll. Measured: 86,412
  tight `readFileSync` reads during 200 replaces never saw half a file and never failed.
- **Open, read, close** - never keep a handle open (section 5.1).
- On (re)connect, rebuild the run's view by scanning the whole `trace.jsonl` (streaming, line by
  line; one run was up to tens of MB before), then follow from the end.
- `stderr.log`: tail the same way; header lines `=== attempt N (kind, reason) <time> ===`.

### 3.3 Latency

- claude writes each event as one line as it happens; the app adds its poll interval
  (250-500 ms is plenty; `fs.watch` can wake it earlier).
- Granularity is the event, not the token: assistant text arrives as whole blocks; a long tool
  call shows nothing until its `tool_result` (in the real trace the longest main-thread gaps
  were 27 s for a Bash call and 65 s for the Agent call); Agent calls emit `tool_progress`
  heartbeats every 30 s and background tasks emit `task_progress`; thinking emits
  `system/thinking_tokens`.
- During a build or a GUI probe (minutes) the trace can be silent; show "tool X running for N s"
  from the open `tool_use`, not "stalled". The loop's own stall detection is the idle watchdog,
  not silence (342 research: a silence timeout would kill reviewers that legitimately wait).

## 4. History and analytics

| Question | Source | Notes |
|---|---|---|
| run list | `.agent-traces/index.jsonl` (`dir, kind, slug, harness, model, started, ended, phase, outcome, feature, attempts`, `traces.py:214-219`) | one line per ended run, in end order; runs still in progress are not in it (`run.json`) |
| outcome | index/meta `outcome` (from the `RUNS.md` row) | `RUNS.md` is complete since 2026-10-18 (109 rows), the traces only cover loop runs and are currently absent |
| durations | `meta.started/ended`; per attempt `started/ended`; claude's `result.duration_ms` per turn | wall vs active time: the gaps between attempts are limit/backoff waits |
| attempts, interruptions | `meta.attempts[]` (`ending`, `error_kind`, `resets_at`, `exit_code`, `idle_killed`), `meta.counters` (`limits`, `errors`, `stalls`, `idles`) | imported runs: `attempts: []`, counters `null` (`traces.md:89`) |
| blocked reasons | `RUNS.md` *Note*, the item's block reason (`backlog/items/<slug>/desc.md`), `meta.why`, `specs/<BRANCH>/fix-log.md` on the stopped branch | |
| per-area throughput | the item's `area` field - **but a closed item's folder is deleted** (`BL remove`, `SKILL.md:389`); recover it from git (`git log --diff-filter=D -- backlog/items/<slug>/desc.md`, then `git show <commit>^:…`) or from the FEATURE-HISTORY index by area | cache per run once computed |
| cost and tokens | scan each `trace.jsonl` for `result` events: per attempt the last `total_cost_usd` / `modelUsage` | not in meta/index; cache per run (an indexed run never changes) |
| person steps, new Inbox items | `RUNS.md` *Inbox*, *Person steps* columns | |
| commits | `meta.commits` (only `[NNN]` and `backlog: <slug>` subjects) | add `[Spec Kit]` commits by `git log <base>..` if wanted |
| triage history | runs with `kind: triage`, `outcome: triaged`, commits `backlog: auto-triage …` | |

Replay of an old run: `trace.jsonl` is the full transcript of all attempts in order. Render it as
a timeline split at separator lines; phase bands from the Skill / Agent / Bash markers of 1.3;
subagent events folded under their `Agent` call (`parent_tool_use_id`); tool calls paired by id;
cost per attempt from its last `result`. Timestamps exist only on `assistant`/`user` events (UTC)
- interpolate others. Serve pages from the server (a big run is tens of MB; 142 runs were 547 MB).

## 5. Hazards - what the web app must never do

### 5.1 File handles and atomic replaces (measured)

- **Never keep a file open** that the loop or a run replaces. Measured: while a Node fd was open
  on a file, Python's `os.replace` onto it failed with `PermissionError` (WinError 5) and the old
  content stayed. Consequences: the loop retries `loop.json`/`run.json` writes for 5 s and then
  **crashes** (`loop.py:145-154`); `meta.json` writes give up after 2 s (`traces.py:143-157`);
  `BL lock update` and `BL run-log` use `backlog.write_text` **without any retry**
  (`backlog.py:172-185`) - a run's step would fail. Read-and-close only.
- Even short reads collide: a tight read loop made the writer retry 154 times in 200 replaces.
  Poll at ~1 Hz, not in a tight loop; read the lock file and `RUNS.md`/`BACKLOG.md` rarely during a
  run, or read them from git objects (`git show main:backlog/RUNS.md`) which opens no working-tree
  file.
- Do not `fs.watch` directories inside the working tree (`specs/<BRANCH>/` etc.): a directory
  handle can keep `git checkout` from removing that directory when a run switches branches
  (inference from Windows sharing rules, not measured). Watching `.agent-traces/` (ignored) or
  `.git/tandem-backlog-loop/` is harmless to git, but polling is enough.

### 5.2 The lock, the records, the tree

- **Never create, update or delete the run lock** (`.git/tandem-backlog-run.lock`); the loop
  itself never does (`loop.py:18-20`, FR-8). `lock release --force` is a maintainer action listed
  in `status`'s *todo* for a `failed`/`lost` run only (`loop.py:1498-1503`); a `STALE` lock during
  a long limit wait is still the run's (`SKILL.md:84-85`).
- Never delete or edit `loop.json`, `run.json`, `triage.json`, `imported.json`; never pass
  `--forget-run` without the maintainer's explicit action (the lock stays and the next precheck
  waits for ever until it is cleaned up).
- **Never make the working tree dirty.** The precheck requires `git status --porcelain` empty
  (`loop.py:1128-1134`) and a run's `git add -A` (`SKILL.md:250`, `:438`, `:556`) commits any
  untracked, not ignored file into the feature. The app's `node_modules/`, build output, caches,
  logs and settings must be ignored by git or live outside the tree (e.g. `.git/tandem-backlog-app/`
  or `%LOCALAPPDATA%`). Note: this session's own `.specify/feature.json` change already makes the
  tree dirty - a loop started now would wait with "the working tree is not clean".
- **No git command that takes a lock while a run may be active**: no `git status` without
  `--no-optional-locks` (or `GIT_OPTIONAL_LOCKS=0`; plain `status` may refresh and write the index),
  no `fetch`, `checkout`, `commit`, `stash`, `gc`, `add`. `git log`, `git rev-parse`, `git show`,
  tree-to-tree `git diff` are fine.
- Do not change the backlog while a run holds the lock or a loop runs unpaused (decision D11,
  `specs/247-backlog-run-loop/spec.md:26`): the run is on its feature branch and a change would land
  in its commit or break the fast-forward.
- Never run the auto-triage while a loop runs: the skill proceeds only when `status` shows the
  loop's pid in state `triage` (`TANDEM_BACKLOG_LOOP_TRIAGE`, `loop.py:105-106`, `:1213`).
- Never start a second loop (refused anyway) or a manual run while the loop is between runs.

### 5.3 Processes (Windows)

- Never `child.kill()` a Python loop from Node: it is `TerminateProcess` without the handler and
  leaves claude running (measured).
- Never kill claude alone: the loop takes it for an error and counts it (measured, scenario C).
- Never touch `~/.claude/projects/<repo>/<session>.jsonl`: `--resume` needs it; a lost transcript
  turns the run into phase `lost` (a stop for a person).
- Hard stop during a GUI probe: warn; the registry backup must be restored before anything else
  (stop-rules §2.8).
- Pid reuse: always compare `pid` and creation time (`ident`), as `loop.py:213-214` does; Node
  needs `status --json` (or a native call) for it.
- Spawning: use `windowsHide`, stdin `ignore`/`DEVNULL` for Python children (an inherited pipe
  stdin stalled the measured target), and `python` directly rather than `bash` (WSL).
- The loop's stdout is UTF-8 (`loop.py:1636-1639`); traces are UTF-8; no code-page decoding.

## Appendix - measurement scripts (scratchpad, not in the repository)

All under `C:\Users\pavel\AppData\Local\Temp\claude\D--Projects-tandemcommander\597f509a-7fdf-4661-a8ce-07059c2577d7\scratchpad\`:

- `scan_trace.py`, `scan_trace2.py` - event types, content blocks, tools, result keys, message ids of a trace
- `loopmeasure.py` - scenarios K (taskkill of the loop tree), C (stop + kill claude only), B (Ctrl+Break) with the real `loop.py` and the fake claude in a scratch repository
- `sig\node_test.mjs`, `sig\wrapper.py`, `sig\target.py` - Node signals vs a Python child; the Python Ctrl+Break relay
- `sig\die_test.py`, `sig\host.mjs`, `sig\child_tree.py` - what survives when the Node host dies; console windows
- `sig\share_test.mjs` - `os.replace` against an open Node handle; tight reads during replaces; `fs.watch` events
