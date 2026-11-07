# Story rules - feature 415

How `RunStory` turns normalised trace events into story entries (data-model *Story entry*). The
rules are applied in this order; the first that matches wins. Unit tests in
`packages/shared/test/run-story.test.ts` cover every row.

## Phases

After each event the embedded `RunState` (existing phase machine) is asked for the phase; a change
opens a `phase` entry, label `PHASE`, title in words:

| phase | title |
|---|---|
| starting | Starting the run |
| selection | Choosing and locking the item |
| measure | Measuring the problem on the current code |
| specify | Writing the specification |
| clarify | Settling the open questions |
| plan | Designing the solution |
| tasks | Breaking the work into tasks |
| analyze | Checking spec, plan and tasks for gaps |
| implement | Implementing |
| verify | Verifying: builds, tests and probes |
| review | Independent review |
| close | Closing the item and writing the records |
| merge | Merging into main |
| done | Finished |
| stopped | Stopped - the item is blocked |
| triage | Triaging the Inbox |

## Main-thread tool calls

| Tool / command (summary) | label | title | outcome from the result |
|---|---|---|---|
| `Skill speckit-<x>` | SPEC KIT | "Runs Spec Kit *<x>*" | ok / fail |
| `Skill <other>` | INFO | "Uses the skill <name>" | ok / fail |
| `Agent`/`Task` | REVIEW when the phase is review or the description says review, else AGENT | "<description>" (+ subagent type) | done when its result arrives; `status` = latest task progress |
| `build.cmd` / `rebuild.cmd` | BUILD | description, else "Builds the program" | `BUILD SUCCEEDED` → ok "build succeeded"; `BUILD FAILED`, `error C`/`error MSB`/`error LNK` → fail **critical** |
| `saltests` | TEST | description, else "Runs the unit rules (saltests)" | `saltests: N checks, M failed` → ok when M = 0, else fail **critical** |
| `npm run check`, `npm test`, `npx vitest`, `vitest`, `playwright`, `npm run test:e2e`, `pytest`, `python -m unittest` | TEST | description, else "Runs the tests" | "N passed" / "N failed" / exit code; failure **critical** |
| `run_on_hidden_desktop.ps1` | PROBE | description, else "Runs a GUI probe on the hidden desktop" | `FAIL` lines → fail **critical**; PASS counts shown |
| `check_encoding.py` | CHECK | "Runs the encoding guard" | `TOTAL: 0` → ok, else fail **critical** |
| `translate.merge` / `translate.slt` | TRANSLATE | description, else "Refreshes translations" | exit |
| `git commit` | COMMIT | "Commits: <subject from -m>" | `[branch hash]` → ok |
| `git merge` / `checkout` / `switch` / `branch` / `rebase` | GIT | description, else "Git: <subcommand>" | exit |
| `backlog.sh` / `backlog.py` `new` | BACKLOG | "Adds an item to the backlog: <title>" | ok → **critical** ("new item for the maintainer's triage"); `--type person-step` → **critical** person step |
| … `block` | STOP | "Stops and blocks the item" | **critical** |
| … `verify` / `start` / `lock` / `run-log` / `remove` / `check` / `move` / `log` / `set` | BACKLOG | "Records the verification" / "Starts the item as feature N" / "Takes the run lock" / "Writes the journal row" / "Closes the item" / "Checks the backlog" / … | exit |
| other Bash / PowerShell | SHELL | description, else "Runs `<command, 80 chars>`" | exit; error → warn |
| `Read` of an image | SCREENSHOT | "Looks at the screenshot <name>" | image listed |
| `Read` / `Grep` / `Glob` / `LS` / `ToolSearch` / `LSP` (consecutive) | READ / SEARCH | one group: "Reads N files: a, b, c …" / "Searches the code (N)" | children list |
| `Edit` / `Write` / `MultiEdit` / `NotebookEdit` (consecutive) | EDIT | one group: "Edits <file> (<component>)" or "Changes N files: …" | error → warn |
| `Write` of an image | SCREENSHOT | "Saves the image <name>" | |
| `TodoWrite` | PLAN | "Updates its to-do list" (low) | |
| `WebFetch` / `WebSearch` | WEB | "Looks up <url / query>" | |
| `ScheduleWakeup` / `Monitor` / `TaskStop` / others | INFO | "<tool>: <summary>" (low) | |

A group ends when an entry of another kind opens. A component is the first two meaningful folders
of the path relative to the repository (`packages/web`, `src/plugins/ftp`, `specs/415-…`).

## Other events

| Event | Entry |
|---|---|
| main-thread `assistant-text` | `message`, label MESSAGE, title = first sentence (≤ 160 chars), detail = the text (Markdown); label DECISION and `decision` when it states one (`decid`, `chose`, `chosen`, `going with`, `I will`, `instead of`, `→ A:`, `autonomous run:`, `conservative`); in phase review with `MUST` → **critical** "review finding" |
| subagent events | children of their agent entry (tool calls in the same human form, texts as "says: …") |
| `task` (`task_progress`, `task_notification`) | updates the `status` of the agent entry with that tool-use id |
| `attempt` n > 1 | `attempt`, label RESTART, "The run continues after <reason> (attempt n)", high |
| `rate-limit` status not `allowed` | `limit`, label LIMIT, "Usage limit reached - the loop waits", **critical** |
| `result` | `turn`, low; `isError` → ERROR **critical** "a turn ended with an error" |
| `init` (first per attempt) | `session`, low, "Claude session starts (model)" |
| `unparsable` | `unreadable`, label ERROR, warn |
| `thinking`, `system` | no entry |

## Importance and the Critical tab

`critical` entries are listed on the Critical tab newest first with their reason; `high` entries are
bold in the story; `low` entries are hidden behind "Show routine steps" (on by default: off).
