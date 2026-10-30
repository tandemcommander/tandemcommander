# Contract: `tools/backlog/backlog.py`

```text
bin/backlog.sh [--root <repo>] <command> [options]
```

(Amended 2026-10-30, feature 344: read commands with JSON output (`board`, `show`,
`check --json`, `legend`), `--ref REF` (read git objects, no working-tree file),
`--input-json -` (texts from stdin), `--json` results of changing commands, and the
commands `reorder`, `body`, `step`, `decide`, `reply`, `set --position` -
`specs/344-backlog-web-app/contracts/backlog-cli-additions.md`. Everything below stays
valid.)

(Amended 2026-10-25, feature 342: `bin/backlog.sh` runs this tool with the same
arguments, output and exit codes, and is the documented way to run it;
`specs/342-backlog-agent-traces/contracts/bin-commands.md`. The Python file is
its implementation.)

`--root` defaults to the repository containing the script. Standard library
only. Output in English, UTF-8, LF line ends (also on Windows).

**Writing.** Every changing command validates its input first (values in
the legend, one-line texts — no `\r`, `\n` or other control characters,
existing references, no `depends-on` on a rejected item or into a cycle,
type-specific body sections present), then writes each file **once**,
atomically (a uniquely named temporary file in the same folder, then
replace) — the item(s) first, `BACKLOG.md` last — and runs the full check.
Exit 1 with the findings when the check fails afterwards (files stay as
written). One writer at a time: the tool takes no lock of its own, so two
processes changing the same tree concurrently can lose rows (measured);
`/tandem-backlog` and `/tandem-backlog-implement` never run two changing
commands at once.

**Rows without an item.** A row of `BACKLOG.md` that has no item link (a
hand-written note) is kept verbatim by every command; `check` reports it
(`overview`) and `sync` refuses while it exists. Rows whose item cannot be
read are kept verbatim too.

Exit codes: `0` success / no findings · `1` check findings or refused
operation (`refused: <why>`) · `2` usage error.

Test hooks (not for normal use): `--lock-dir <dir>` (global option, lock
folder instead of the git common dir), environment `TANDEM_BACKLOG_NOW=YYYY-MM-DDTHH:MM:SS`
(the tool's clock).

## Read-only

| Command | Behaviour |
|---------|-----------|
| `check` | Runs every rule; prints `<path>:<line>: <rule-id>: <message>` per finding, then `TOTAL: <n>`. Exit 1 iff n > 0. A file that is not valid UTF-8 is a finding, never a crash. |
| `list [--section S] [--area A] [--type T] [--status S] [--who W] [--min-severity N] [--needs SLUG] [--related-to SLUG] [--json]` | Items in backlog order (sections top-down, rows in order; *position* counts item rows). `--needs SLUG`: only items whose `depends-on` names SLUG; `--related-to SLUG`: only items whose `related` names it. `--json` prints an array of objects with all header fields plus `section` and `position`. |
| `next [--slug S] [--json]` | The item an autonomous run would take (FR-031): first eligible row of *Next*, or `S` if eligible. Prints the slug, or `nothing-to-do`, and for every skipped row above it the reason (`status blocked`, `who person`, `depends-on <slug>`, …). Exit 0 in both cases. With `--slug S` not eligible or unknown: exit 1; with `--json` the output is still JSON: `{"slug": null, "refused": S, "reason": …}`. |
| `lock status` | `free`, or the lock's fields + age + `STALE` if older than 24 h. |

## Changing

| Command | Behaviour |
|---------|-----------|
| `new --title T --type T --severity N --area A [--source S] [--who W] [--effort E] [--related a,b] [--depends-on a,b] [--slug S] [--problem TEXT] [--evidence TEXT] [--expected TEXT]` | Creates `items/<slug>/desc.md` from the template (status `new`, created/updated today, verified `-`, log "created (source …)"), adds the *Inbox* row. Defaults: `--source manual`, `--who agent`. Refuses an existing slug (naming it) and a title that gives no slug. Prints the slug. Body texts may span lines; header values may not. |
| `import-github N --area A [--type T] [--severity N] [--slug S]` | Fetches issue N and **all** its comments (public REST interface, `per_page=100` with paging; through `gh api` when the GitHub CLI is installed, else anonymously); refuses if the number of fetched comments differs from the issue's count, if an item with `source: github#N` exists, or on a network error (nothing written). Writes `issue.md` verbatim and `reply.md` (`state: not-sent`), creates the item as `new` with `who: agent`, title = issue title, *Problem* = the first paragraph of the body that is not a heading. Default `severity 5`; default type from the issue's labels: `bug` → `bug`, else `enhancement` → `feature`, else `documentation` → `improvement`, else `bug`. `issue.md` records the labels. |
| `import-github --label L [--area A] [--severity N] [--dry-run]` | Imports every **open** issue labelled L (paged list, pull requests excluded) that is not yet in the backlog, oldest number first, each as above; area default `panels-ui` (`help-docs` for a `documentation` type), severity default 5 — placeholders the skill corrects. Skips, one line each: `skipped #N: <why>` for a pull request, an issue an item holds (`source: github#N`), an issue labelled `fixed` / `duplicate` / `invalid` / `wontfix`, and an issue whose `source: github#N` appears in the git history of `backlog/items/*/desc.md` (imported before, its item removed since — `git log -G`; no repository or no commit yet = no history). The area and severity are validated, and all skips decided, before anything is written (also for `--dry-run`). Per issue `imported #N <slug>` or `failed #N: <reason>` (comments not read, slug exists; the others go on); last line `imported n, skipped n, failed n`. Exit 1 if any failed or the check has findings. `--dry-run` prints `would import #N [labels] as <type>, <area>: <title>` and writes nothing. A listing error writes nothing. `--slug` / `--type` are refused with `--label`. |
| `set <slug> key=value… [--log TEXT]` | Changes header fields other than `status` / `updated`; validates the result (values, references, rejected / cyclic dependencies, type-specific body sections) **before writing**; sets `updated`; appends a log line (`--log`, or "set k=v, …"). `title` may change (also the body's first line); the slug never changes. A change of `type` / `who` that changes the section moves the row to the end of the fitting section. |
| `log <slug> TEXT` | Appends a log line, sets `updated`. |
| `verify <slug> [--commit C] [--note TEXT]` | `verified = today <C or the short HEAD>` (C: 7–40 lowercase hex, checked before writing), log "verified at C: TEXT". |
| `move <slug> --section S [--position N] [--reason TEXT]` | Moves the row to section S (ordered sections: position N ≥ 1, default end; a position past the end means the end) and sets the status the section implies: *Next* / *Decisions* / *Person steps* → `open`, except that a **`blocked` item stays `blocked`** (log: "still blocked: <reason>"; use `unblock`); *Parked* → `parked`, *Rejected* → `rejected` (both need `--reason`); *Inbox* → `new`. Moving an item **out of** `parked` / `rejected` (to any section) needs `--reason` (the new reason; logged as "reopened: …"). *In progress* is refused (only `start`). Refuses a section that does not admit the item's type / who. Sets *Last triaged* to today on every move except a move to *Inbox*. An item without a row (`orphan`) gets one. |
| `block <slug> --reason TEXT` / `unblock <slug> [--note TEXT]` | `open` → `blocked` with reason / `blocked` → `open`, row stays in place. |
| `start <slug> --feature NNN` | Eligible item (as `next`) only: `open` → `in-progress`, `feature = NNN`, row to the end of *In progress*, log "run started, feature NNN". |
| `remove <slug> --feature NNN [--force]` | Feature NNN closed the item: requires status `in-progress` with that feature (`--force`: any status). Deletes the folder first (read-only files included), then the row, then removes the slug from every other item's `related` / `depends-on`, logging "dependency <slug> done in feature NNN" there. |
| `remove <slug> --reason TEXT` | Close without a feature (maintainer: the item turned out already fixed, or not reproduced and accepted as such). Refused for `in-progress`. Same deletion; dependents log "dependency <slug> closed: TEXT". |
| `sync` | Rewrites derived cells and numbering of every table from the items. Refuses (exit 1) while rows and items do not correspond one-to-one, or while `BACKLOG.md` has structural or row findings (`overview`), listing them. |
| `run-log --outcome O [--slug S] [--feature NNN] [--branch B] [--inbox N] [--person TEXT] [--note TEXT]` | Appends one row to `RUNS.md` with the current local time; line breaks in texts become spaces. |
| `lock acquire [--slug S] [--branch B]` | Creates the lock exclusively; exit 1 with the holder's fields if it exists. |
| `lock update --slug S --branch B` | Records the branch in the lock this run holds (slug must match). |
| `lock release [--slug S]` / `lock release --force` | Removes the lock if its slug matches (no `--slug` matches a lock acquired without one); `--force` unconditionally — for the maintainer. Exit 1 if there is no lock. |

## Check rules (`rule-id`)

| Rule | Finding |
|------|---------|
| `layout` | unexpected file or folder at `backlog/` top level or in an item folder (also leftover `*.tmp~`); missing `BACKLOG.md`, `RUNS.md`, `RELEASE.md` (a missing `items/` counts as empty) |
| `slug` | folder name violates the slug pattern |
| `desc-missing` | item folder without `desc.md` |
| `header` | not valid UTF-8, a BOM, header missing, keys missing / extra / out of order, malformed line |
| `value` | a value outside its vocabulary or format (severity, dates, commit, one-line texts), `updated` < `created`, a `person-step` whose `who` is not `person`, a status without a section rule, `reply.md` first line |
| `required` | `reason` / `feature` missing for the status, or present when not allowed |
| `feature-missing` | `in-progress` with no `specs/<feature>-*` folder |
| `body` | first line not `# <title>`, unknown or repeated `## ` section, sections out of order, a required section missing, *Log* empty / malformed / dates decreasing, *Steps* without a checklist line. Headings inside fenced code blocks are ignored. |
| `ref` | `related` / `depends-on` naming a missing item or itself; `depends-on` a rejected item |
| `cycle` | a `depends-on` cycle (lists its members) |
| `github` | `github#N` without `issue.md` or with a wrong first line; two items with the same `github#N` |
| `orphan` | item folder without an overview row |
| `dangling` | overview row whose item does not exist |
| `duplicate` | item listed more than once |
| `section` | item in a section that does not admit its type/status/who |
| `derived` | a derived cell, the row order of an unordered section or a row number differs from what `sync` would write |
| `overview` | not valid UTF-8, a section heading missing / out of order, a section without exactly one table, a row without an item link or with a wrong cell count, the *Last triaged* line, a legend table missing |
| `runs` | `RUNS.md` table malformed or an outcome outside the list |
