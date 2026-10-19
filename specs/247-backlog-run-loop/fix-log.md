# Fix log — 247 backlog run loop

Running record (CLAUDE.md *Working method*). Design: `spec.md`; contract:
`contracts/loop-cli.md`.

## 2026-10-19 — measurements before writing anything

Claude Code 2.1.303 (`claude --version`), Git Bash, Python 3.14.6.

| # | What | Command (scratchpad, model haiku) | Result |
|---|---|---|---|
| M1 | a session id chosen by the caller, then continued | `claude -p 'Reply with the single word: alpha' --session-id <uuid> --output-format json`, then `claude -p 'What word did you reply with before?' --resume <uuid> --output-format json` | both exit 0, `session_id` the same in both, the second answers `alpha` — the context is kept |
| M2 | the shape of an API error | `claude -p hi --model claude-no-such-model-1 --output-format json` | exit 1, `{"type":"result","is_error":true,"api_error_status":404,"terminal_reason":"api_error","result":"There's an issue with the selected model…"}` |
| M3 | continuing an unknown session | `claude -p hi --resume 00000000-0000-4000-8000-000000000000` | exit 1, stderr `No conversation found with session ID: …`, no JSON |
| M4 | stream-json | `CLAUDE_CODE_RETRY_WATCHDOG=1 claude -p '…echo…' --output-format stream-json --verbose` | lines `system/init`, `assistant`, **`rate_limit_event`**, `user`, `assistant`, `result/success`; the rate event carries `status` (`allowed_warning`), `resetsAt` (unix), `rateLimitType`, `utilization`, `unifiedWindows.{five_hour,seven_day}` — the maintainer's weekly window was at 93 % |
| M5 | how claude itself treats usage limits | strings of `claude.exe` 2.1.303 (changelog 2.1.301) | an *unattended retry mode* `CLAUDE_CODE_RETRY_WATCHDOG`: a 429 with `anthropic-ratelimit-unified-status: rejected` waits until `anthropic-ratelimit-unified-reset`, bounded by `CLAUDE_CODE_RETRY_WATCHDOG_MAX_USAGE_LIMIT_WAIT_MS` (unset = no bound); 429/529 otherwise bounded by `…_MAX_WAIT_MS` |
| M6 | can a 429 be simulated? | `CLAUDE_MOCK_HEADERLESS_429=1 [CLAUDE_CODE_RETRY_WATCHDOG=1 …_MAX_WAIT_MS=20000] claude -p hi` | both answered normally in 5–7 s: the mock is not active in the public build. **A real usage limit cannot be produced here** → NOT DRIVEN, owed to a person |

Consequences for the design: the loop picks the session id itself (`--session-id`),
continues with `--resume` (M1), recognises a lost session from stderr (M3), reads limits
from `rate_limit_event` and the result's `api_error_status` (M2, M4), and lets claude wait
out limits in-process (M5) — the loop's own limit handling is the fallback for a process
that ends anyway.

### Found on the way

- `python -m unittest tools/backlog/test_backlog.py` at `main` (e6442151): **28 failures,
  2 errors of 68**. The valid fixture needs the empty folder `specs/243-example/`, which git
  never stored. With the folder created by hand: 68 OK (also with this feature's
  `next_eligible` refactor). Not fixed here (*one by one*): Inbox item
  `backlog-fixture-empty-specs-folder-missing` (`measure:247`). `test_loop.py` creates the
  folder (with a file) in its own copies.

## Implementation

- `tools/backlog/loop.py` — the loop, the four control commands, status (stdlib).
- `tools/backlog/loop-{start,pause,resume,stop,status}.sh` — one-line wrappers
  (`exec "${PYTHON:-python}" -u loop.py <cmd> "$@"`), LF (`.gitattributes` already has
  `*.sh text eol=lf`), a `#!/usr/bin/env bash` line (Git Bash runs `./tools/backlog/loop-start.sh`
  by it; git stores mode 100644 like the other 14 `.sh` files of the tree, `core.filemode=false`).
- `tools/backlog/backlog.py` — `next_eligible()` taken out of `cmd_next` so that the loop
  uses the same rule (no behaviour change; `test_backlog.py` 68 OK with the fixture folder).
- Skills: `/tandem-backlog-implement` §0.11 *Continued run*; `/tandem-backlog` §0.2
  *Not during a run* (maintainer mode refuses changes while the run lock is held).
- `CLAUDE.md`: the backlog row names the loop scripts.

Traps met:
- Git Bash passes `\\` of a JSON argument to a native program as `\` (the test of the
  wrappers failed with `invalid loads value`) — the CLAUDE.md trap of 123 again; the test
  passes forward slashes. Only the hidden test option `--claude-cmd` takes JSON.
- A refused second start must not run the cleanup of the loop it refused (it would remove
  that loop's pending stop): `register()` is outside the `try/finally` of the cleanup.

- The first mutation run hung on its third mutant (`finished-ignores-the-lock`): the
  in-process loop of a test waited for ever for a lock that nobody would release — the
  defect was caught, but as a hang. Added the hidden `--deadline` (tests: 60 s; the loop
  kills its claude and ends with exit 3) and a 30-min timeout per mutant in
  `mutate_loop.py`; the stopped run left no process behind (checked by command line).

## Review round 1 (independent agent, refute-first) — 2 MUST, 4 SHOULD, 8 NOTE

| # | Finding | Done |
|---|---|---|
| M1 | "the item holds the lock" compared only the slug: a manual run of the same item taking the lock first made the loop's refused run look stalled — continued twice into the manual run's working tree, then `failed` with advice to force-release the manual run's lock (reproduced) | `holds()`: the item's lock, taken after the run started, and — once seen — the same lock (`started`); a refused result under such a lock is `refused`, never continued. Tests: refusal under another run's lock, another item's lock, a lock taken before the run, a replaced lock |
| M2 | Git Bash (`kill -TERM` on the wrapper) kills loop and claude at once; no handler runs, `run.json` stays `running`; the contract claimed the process group protects claude | the next start says the run was cut off (with the registry hint) and continues it; status says so too; contract and spec FR-7 corrected; the person step asks which of the two behaviours a typed Ctrl+C shows. Test: a run record `running` with a dead claude |
| S1 | a `rejected` rate event before a successful end (claude waited the limit out) made later stalls / errors "limits" — unbounded (reproduced: 6 stalls) | `limited` is false for a successful result. Tests (log + loop) |
| S2 | limit continuations unbounded; `limit reached` matched `Context limit reached` (reproduced: 8 resumes) | `MAX_LIMITS = 10` → `failed`; the text rule only for an error without an HTTP status and only usage / session / weekly / five-hour limit or "hit your limit". Tests |
| S3 | the skill rule protected only while the lock is held; an idle loop can start a run between two commits of a triage | `/tandem-backlog` maintainer mode also refuses while a loop runs unpaused; spec D11 |
| S4 | Ctrl+C that also ended claude → "no item was running", no hint | hard stop whenever the loop had a child. Test |
| N1 | a stop left by a killed loop ended the next start at once | a start removes it. Test |
| N2 | another item's journal row taken as this run's outcome | `our_row()` matches the item. Test |
| N3 | step 10 failing between release and journal looked like a refusal | verdict `unrecorded` with its own message (same bound) |
| N4 | a claude started between `Popen` and the save of its pid would be invisible to the next loop | not changed: the window is the time of one `process_ident` call + one file write |
| N5 | status said HARD STOP while the loop waited for a previous loop's claude | status follows `ctrl_c_safe` of `loop.json` |
| N6 | `PermissionError` of the lock read; a run waiting > 24 h shows its lock STALE | lock read retries; `save_json` retries 5 s; SKILL.md §0.11 says the STALE lock is still the run's |
| N7 | docs: stop vs an interrupted item, "closing the console", the executable bit, `.cmd` shims | contract (stop), FR-7; the bit is not set (like every `.sh` of the tree; the round-1 note here wrongly said it was — round 2 N11); claude is `claude.exe` here |
| N8 | three of the reviewer's mutants survived (log offset ignored, another item's lock in pending, any holder) | tests added; `mutate_loop.py` extended from 21 to 34 mutants |

E2E with the real claude after round 1: 5/5 PASS.

## Review round 2 (a fresh agent, refute-first) — 0 MUST, 2 SHOULD, 11 NOTE

| # | Finding | Done |
|---|---|---|
| S1 | introduced by the M1 fix: a **continued** run that ended `Outcome: refused` while holding its own lock had its record (the session) dropped; the loop then waited for ever on its own lock (reproduced) | `refused` only for a first attempt whose lock the loop never saw; otherwise `refused-own` → phase `failed`, record kept, stop (1). Test |
| S2 | the N5 fix did not hold: `watch()` announced `safe=False` on every tick, also while waiting for a previous loop's claude (reproduced) | `watch(…, safe)`; the orphan wait passes `True`. The orphan test now checks status while waiting |
| N1 | `holds()` can misjudge the run's own lock: `TANDEM_BACKLOG_NOW` inherited by claude (reproduced), a clock step back > 2 s | the test clock is removed from claude's environment (test); a same-item lock judged foreign makes the wait text point to `loop-status.sh`; a clock step remains a known limit |
| N2 | a manual run taking the lock in the seconds between the precheck and the skill's acquire while our run crashes still counts as ours; `**Outcome:** refused` not recognised | the Markdown form is recognised (test); the crash-in-the-race case remains a known limit (the lock file has no session id; changing the lock format is the skill's contract, feature 242) |
| N3 | an error after a limit claude had waited out was taken as a limit (30 min instead of the 1-min backoff) | a `rejected` event counts only when there is no result. Test |
| N4 | "released by hand?" for a run cut off before it took the lock | its own message |
| N5 | status without a loop but with the previous claude alive said "continues this run" | says the claude is still working and the next start waits for it (test) |
| N6 | `Repo.runs()` returned `[]` on `PermissionError` → a false `rows_before` | retries like the lock read; then raises |
| N7 | the lock's age in the wait text changed it every 6 min (new window line, `since` reset) | `lock_words()` without the age |
| N8 | pausing while an interrupted run waits keeps its lock — the skill rule's "wait for lock free" never comes | `pause` says so; contract |
| N9 | the status `todo` used `BL` and `<slug>`, no commit | full commands with the slug and the commit |
| N10 | Ctrl+C during a limit wait said "no item was running" | says the interrupted run keeps the lock and is continued |
| N11 | FR-3 wording; the executable-bit claim | FR-3 corrected; the claim corrected (see N7 of round 1) |

E2E with the real claude after round 2: 5/5 PASS.

## Tests

Final state: `python -m unittest tools/backlog/test_loop.py` — **57 tests OK** (about 95 s);
`tools/check_encoding.py --strict` `TOTAL: 0 finding(s)`; `backlog.py check` `TOTAL: 0`;
`test_backlog.py` 68 OK with the fixture folder created by hand (see *Found on the way*).

Negative controls `probe/mutate_loop.py` (39 mutants of `loop.py`, run 2026-10-19 after
round 2): **38 caught** — `slug-not-passed` by hanging the tests (the run was stopped by
hand after 24 min instead of its 30-min timeout); **1 survived**, `success-counted-as-limit`:
after the round-2 fixes it differs only for a *successful* result whose text names a usage
limit (both other limit signals already require an error / no result) — near-equivalent,
left as is.

E2E with the real claude (`probe/e2e_real_claude.py`, model haiku): 5/5 PASS three times
(first version, after round 1, after round 2): a fresh session for the first eligible item,
status `HARD STOP now` while it runs, Ctrl+Break → exit 130 + claude tree killed + lock
kept, the next start continued the same session and the item closed (journal row, lock
free), one log with one session id. After the continuation the model first checked
branch, status and lock, then finished — as SKILL.md §0.11 says.

The first version had 42 tests (about 50 s): runs in order,
model / watchdog / flags of the claude command, `--max-items`, blocked streak, outcomes,
limit with and without a reset time (continuation in the same session after the reset),
error backoff and its end, stalls, a lost session, refusals, errors before the item was
taken, a row written while the lock is held, claude missing, usage errors; precheck
(lock, branch, dirty tree, check findings, nothing eligible); as processes: pause / resume /
stop, stop while an item runs, a pause set before the start, waiting for a clean tree, one
loop per repository, a dead loop's record, **Ctrl+Break while an item runs (the fake claude
is killed, the next start continues the session)**, Ctrl+Break while waiting, a claude left by
a killed loop is waited for; control commands without a loop, files only in `.git`, the five
wrappers through Git Bash (LF checked); log parsing, usage line, partial lines, process
identity (pid reuse), log pruning.
