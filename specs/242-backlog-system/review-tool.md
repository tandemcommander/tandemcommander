# Review — feature 242 backlog tool and skills (refute-first)

**Date**: 2026-10-17 · **Reviewer**: independent agent · **Mode**: no repository
file changed except this report; every reproduction ran on copies in a
scratch folder (`--root <copy>`, `--lock-dir <tmp>`).

**Reviewed versions** (the files were being edited during the review; the
findings refer to these, re-read at 10:44–10:46):

| File | sha256 (12) |
|---|---|
| `tools/backlog/backlog.py` (1684 lines) | `231fe0e6f416` |
| `tools/backlog/test_backlog.py` | `28de25861a06` (33 tests incl. `test_move_restores_orphan_row`) |
| `.claude/skills/tandem-backlog/SKILL.md` | `c12f0e9b922c` |
| `.claude/skills/tandem-backlog/reference.md` | `5157ba63e77e` |
| `.claude/skills/tandem-backlog-implement/SKILL.md` | `014a074f5345` |
| `.claude/skills/tandem-backlog-implement/stop-rules.md` | `9fa376da3544` |

`python -m unittest tools/backlog/test_backlog.py -v` → OK; `backlog.py check`
on the real backlog → `TOTAL: 0`.

Counts: **2 MUST · 15 SHOULD · 17 NOTE**.

---

## Findings

### MUST

| # | Where | Problem | Reproduction | Suggested fix |
|---|---|---|---|---|
| M1 | `tandem-backlog-implement/SKILL.md:146`, `:156`; `stop-rules.md` §3 #8; `.claude/skills/speckit-specify/SKILL.md:91`; `.specify/extensions/git/scripts/bash/create-new-feature.sh:170-176` (same in `powershell/create-new-feature.ps1:124-141`) | **The branch number and the spec-folder number diverge after any unmerged numbered branch — which every stopped run leaves behind.** `create-new-feature` numbers the branch from max(branches incl. remotes, `specs/`)+1; `speckit-specify` numbers the folder from `specs/` only ("next available 3-digit number after scanning existing directories in `specs/`"). The stopped run's branch `243-x` carries `specs/243-*` only on the branch, so the next run gets branch `244-y` and folder `specs/243-y`. Step 4 then requires `ls -d specs/<NNN>-*` with NNN = FEATURE_NUM (244) → fails → stop-rules §3 #8 "Spec Kit did not create the feature" → the item is **blocked on `main` although nothing is wrong with it**, and the stop commits another numbered branch, so every later run fails the same way. If the agent instead uses the folder number, two features share number 243 (the stopped one and the new one). | Temp repo with `specs/241-prev` on `main` and a branch `242-stopped-run`: `create-new-feature.sh --json --dry-run --short-name next-item "Next item"` → `{"BRANCH_NAME":"243-next-item","FEATURE_NUM":"243"}`, while `specs/` scanning gives 242. | In step 4 pass the folder explicitly: invoke `speckit-specify` with `SPECIFY_FEATURE_DIRECTORY=specs/<BRANCH_NAME>` (the skill uses an explicit value as-is, `speckit-specify/SKILL.md:87`), and say "NNN = FEATURE_NUM; the folder must be `specs/<BRANCH_NAME>`". Add a dry check to step 4 (branch number == folder number) and a quickstart scenario "run after a stopped run". |
| M2 | `backlog.py:579-580` (`render_table` keeps only rows with a slug), `:1176-1191` (`cmd_sync`) | **`sync` (and every changing command) silently deletes a hand-written row that has no item link, exit 0.** `parse_overview` records the row with `slug=None`; `render_table` drops every `slug=None` row; `cmd_sync` checks only the slug↔item correspondence, not `ov.errors`, prints `synced`, exit 0. The maintainer is explicitly allowed to edit `BACKLOG.md` rows by hand (`tandem-backlog/SKILL.md:82`, then "run `BL sync`"), and reference.md §6 sends `derived` findings to `BL sync` — so a note row typed by the maintainer is lost by the documented repair. (Free text between tables survives; only `|`-rows without a link are lost.) | Insert `\| - \| TODO: ask Pavel about the FTP server (no item yet) \| \| \| \| \| \| \|` into *Next* of a fixture copy → `check` reports `overview: row without an item link` → `sync` prints `synced`, exit 0 → the row is gone. | Keep link-less rows verbatim in `render_table` (as dangling rows already are, `:583-585`), and make `sync` refuse (exit 1) while `overview` row errors exist, naming the line. |

### SHOULD

| # | Where | Problem | Reproduction | Suggested fix |
|---|---|---|---|---|
| S1 | `backlog.py:110`, `:517-518` | The row identity is the **first** `(items/<x>/desc.md)` in the line, so a title containing that text (plausible for `tooling` items about the backlog itself) hijacks the row. With an existing slug inside the title, the next unrelated command rewrites the new item's row as a second copy of the other item: the new row is lost (orphan), the other item is duplicated. | `new --title "Duplicate of (items/ftp-per-server-encoding-flag/desc.md) here" …` → exit 1 (`duplicate`, `orphan`); then `log disk-map-context-menu-crash touch` → line 45 now reads `[FTP per-server encoding flag](items/ftp-per-server-encoding-flag/desc.md)`. With `(items/<slug>/desc.md)` in the title: `dangling` + `orphan`. | Match the link target, not any parenthesis: `(?<!\\)\]\(items/([^/()]+)/desc\.md\)` and take the **last** match; or escape `(`/`)` in `esc_link_text`. Add the title to the fixture. |
| S2 | `backlog.py:286-289`, `:1140-1157`, `:1271-1291`, `:1344-1358`, `:1393-1399` | A newline in any header-bound value (`--title`, `--reason` of `block`/`move`, `set key=value`) is written into the header and **corrupts it**; afterwards every tool command refuses the item ("malformed header"), and the documented repair is impossible: reference.md:278 says "restore the header with `BL set` (never by hand)", but `set` refuses a malformed header. The overview row of a new item with such a title degenerates to `\| [slug](items/slug/desc.md) \|`. | `block ftp-per-server-encoding-flag --reason "$(printf 'waiting\nsecond line')"` → desc.md line 17 `second line`; `unblock …` → `refused: … malformed header`. `new --title "$(printf 'Two\nlines')" …` → row with 1 cell. | Refuse values containing `\r`/`\n` (or any control character) before writing, in `base_header`, `set`, `move`, `block`, `verify --commit`. In reference.md §6 say "`git checkout`/`git restore` the item" for `header` findings. |
| S3 | `backlog.py:655-669`, `:1384-1389` (`move`), `:1429-1432` (`start`), `:1303-1307` (`set` relocation) | The contract's "never leaves a half-written file" holds per file, but these commands write `BACKLOG.md` two or three times in sequence (row removed, then row added, then *Last triaged*). A failure between the writes (Windows sharing violation from an AV scanner, a crash) persists the intermediate state: the item has its new status and **no row**. | Monkey-patched `os.replace` to fail on the 2nd write of `BACKLOG.md` during `move typed-path-with-a-pipe-brackets --section next --position 1` → `orphan` + leftover `BACKLOG.md.tmp~` (`layout`). | Do the row change and *Last triaged* in memory and write `BACKLOG.md` once per command; write the item last (or first, but only once). |
| S4 | `backlog.py:161`, whole tool | Concurrent use is unsafe: a fixed temp name `BACKLOG.md.tmp~` per file and read-modify-write of the overview without a lock. Two sessions in the same tree lose rows. The spec's edge case "two sessions add items at the same time — the result merges as independent rows" (`spec.md:219`) is also false for git: two branches each adding an *Inbox* row insert at the same place and conflict. | 8 parallel `new` → 1 exit 0, 7 exit 1; 8 folders, 5 rows (3 orphans), 2 tracebacks `PermissionError … BACKLOG.md.tmp~`. Git: branch `side` and `main` each `new` → `git merge side` → `CONFLICT (content): Merge conflict in backlog/BACKLOG.md`. | Document both (management skill: one writer at a time; resolve an *Inbox* conflict by keeping both rows, then `BL sync`). Optionally: per-process temp names (`tempfile.mkstemp` in the folder) and an exclusive `backlog/.lock`-style file lock (outside `backlog/`, or excluded from `layout`) around read-modify-write. Correct the spec edge case. |
| S5 | `backlog.py:152-155`, `:622-628` | A non-UTF-8 `desc.md` or `BACKLOG.md` (e.g. saved as cp1250 by an editor) makes **every** command, including `check`, die with a `UnicodeDecodeError` traceback instead of a finding (FR-015 "report per finding", FR-022). | Write a fixture item in cp1250 with "Žluťoučký kůň" → `check` exit 1 with a traceback, no `TOTAL:` line; `list` the same. | Catch `UnicodeDecodeError` per file in `parse_item` / `parse_overview` / `runs_findings` and report `header` (or a new `encoding`) finding with the byte offset; mark the item not-ok. |
| S6 | `backlog.py:361-367`, `:379-396`, `:770-816` | Headings are recognised inside fenced code blocks. A `## Log` (or any `## X`) inside a fence in *Evidence* — likely for items quoting a template or an issue — gives false `body` findings, and `append_log` writes the next log entry **into *Evidence*** (it uses the first `## Log`). | Add to *Evidence* a fenced block containing `## Log` / `- 2026-01-01 — created` → `check`: "appears more than once", "out of order"; `log … "where does this go"` → the entry lands after the fence inside *Evidence*. | Track fences (```` ``` ````/`~~~`) in `headings()` and `body_findings()`; ignore headings inside them. |
| S7 | `backlog.py:1522`, `:1529`, `:1076-1088` | `import-github`: comments are fetched without `per_page`/pagination (GitHub returns 30) — issues with more comments are **silently truncated** although `issue.md` is promised "verbatim"; the *Problem* is the first paragraph verbatim, so a body starting with a `## ` heading (common issue style) produces an item that fails `check`. | Fake fetch with body `## Describe the bug\nCopy crashes.…` → exit 1, `body: unknown section '## Describe the bug'`. Pagination by reading (`fetch_json(base + "/comments")`, `gh api` without `--paginate`). | Use `?per_page=100` and follow `Link: rel="next"` (`gh api --paginate`); fail if the fetched count ≠ `issue["comments"]`. Strip leading `#` heading lines from the *Problem* paragraph (or quote it as `> …`). |
| S8 | `backlog.py:1363-1369`; `contracts/cli.md:34`; `reference.md:256` | `move` to *Next*/*Decisions*/*Person steps* keeps `blocked` **even with `--reason`**; the contract says it keeps `blocked` only "if `--reason` not given". reference.md documents the code, so contract and skill disagree. The log then says "moved to Next position 2: server available now" while the item stays blocked with the old reason. | `move disk-map-context-menu-crash --section next --position 2 --reason "server available now"` → `status: blocked`, `reason: needs a real mouse`. | Decide one rule; simplest: change the contract to the code's behaviour and log `(still blocked: <reason>)`; or unblock when `--reason` is given. |
| S9 | `backlog.py:1359-1361`, `:1379-1380` | `move` of a *Rejected*/*Parked* item to *Inbox* needs no reason (the data model: re-opening needs a new reason) and logs the literal text **`(reopened: None)`**. | `move b-2-systemic-comparison --section inbox` → exit 0, log `- 2026-10-17 — moved to Inbox (reopened: None)`. | Require `--reason` whenever the old status is `parked`/`rejected`, whatever the target. |
| S10 | `tandem-backlog-implement/SKILL.md:186-193`, `:305-330`; `stop-rules.md` §3 last paragraph | On a stop after the branch exists, items recorded during §5 (`measure:NNN`, `review:NNN`) are committed **only on the unmerged branch**; step 10.3 records only the decision / person-step / split items on `main`. The final message's "New Inbox items" and `INBOX` count include items that are not on `main`; "A stop leaves … the new items in *Inbox*" is false for them. | Walk-through of path (b). | In step 10, after `git checkout main`, re-create (`BL new`) the out-of-scope findings recorded on the branch (keep their slugs; list them from `git diff main..<BRANCH> --name-only -- backlog/items`), or record them on `main` at the moment they are found (not possible while on the branch) — the former is simpler. |
| S11 | `tandem-backlog-implement/SKILL.md:296-303`, step 10 | Fast-forward failure: the branch already holds `BL remove` + a `closed` journal row; `main` then gets `block` + a `blocked` row for the same run. The prescribed "merge it by hand" conflicts in `RUNS.md` (both append at the table end) and is a modify/delete conflict on the item; resolved naively, the journal says the run both closed and blocked. | Walk-through of path (f) (git behaviour as measured in S4). | Tell the maintainer in the reason and the closing message how to resolve: take the branch's removal, drop the `blocked` log line, keep both journal rows (or add `--note 'superseded by <BRANCH>'`). Alternatively record the FF failure with a distinct outcome (`ff-failed`) so the journal is unambiguous. |
| S12 | `tandem-backlog-implement/SKILL.md:93`; `backlog.py:1489-1500`; FR-039 | The lock is acquired before the branch exists (`--slug` only) and there is no command to add the branch later, so the lock **always** says `branch -`. FR-039 requires the lock to hold the branch and a refused run to name it. | `lock acquire --slug x` then `lock status` → `… branch -, host …`. | Add `lock update --slug S --branch B` (or `start --branch` writing it) and call it in step 4 after `BL start`. |
| S13 | `tandem-backlog/SKILL.md:54-57` (quoting advice); `CLAUDE.md` "Bash here-documents collapse doubled backslashes (123)" | The skill says to put texts with `\` in single quotes for the Bash tool. On this machine the Bash tool's transport collapses `\\` to `\` **even inside single quotes**: UNC paths and `\\?\` prefixes — frequent in this project's items (long paths) — are stored mangled in *Problem*/*Evidence*. | `printf '%s\n' '\\server\share'` → `\server\share`; `new --problem 'a \\server\share'` → desc.md `a \server\share`. | Skill: "texts containing `\\` (UNC, `\\?\`) never go on the command line — create the item with a placeholder and write the text with the Edit tool; then `grep` it back". |
| S14 | `tandem-backlog/SKILL.md` §1 table and §2; reference.md §6 | The management skill has **no operation for `unblock`** (the tool command exists; reopen via `move` keeps `blocked`, S8), and **no way to close an item that turned out done / not reproduced**: §2.8 offers only `reject`, but `rejected` means "decided not to do" and every item that `depends-on` it then gets a `ref` finding ("rejected and never done") and is never eligible. After a run's `not-reproduced` stop this is the common case. | Reading; `ref` behaviour at `backlog.py:902-903`. | Add `unblock <slug>` (maintainer mode) to §1/§2; add a "close as already fixed" path — e.g. tool `remove <slug> --reason 'fixed by <commit/feature>'` without `--feature`, which also drops it from dependents' `depends-on` and logs it. |
| S15 | `tools/backlog/test_backlog.py` | The tests prove much less than they appear to. Negative controls (one mutation each in a copy of `backlog.py`, full suite run): **15 of 19 mutants survive** (14 rule mutants below + non-atomic writing) — duplicate `github#N` detection off (an FR-015 rule; SC-004 claims one seeded defect per FR-015 rule), `updated < created` off, decision-before-person precedence swapped, log date order off, self-reference off, `depends-on` a rejected item off, `remove` not cleaning `related`, *Inbox* not sorted, `## Steps` checklist rule off, body title-line check off, `verified` format off, **`start` ignoring eligibility** (FR-031), `sync` accepting duplicates, `move` turning blocked→open. Caught: `remove` ignoring the feature number, `next` treating blocked as eligible, import duplicate check off, orphan rule off. Atomic writing cannot be told apart from direct writing by any test. | `C:\Users\pavel\AppData\Local\Temp\claude\E--Projects-tandemcommander\2675eba2-4e8e-4b17-b302-cc23d153f8d1\scratchpad\mutate.py` (outside the repository): copies `tools/backlog/`, applies one replacement, runs `unittest`. | Add seeded cases per sub-rule (at least: duplicate `github#N`, self-ref, rejected dependency, `updated<created`, bad `verified`, title-line mismatch, log order, empty *Steps*), a decision item with `who: person` in the fixture, `start` on an ineligible item, `sync` with a duplicate row, `remove` cleaning `related`, and the S1/S2/S6 inputs. |

### NOTE

| # | Where | Observation | Suggested action |
|---|---|---|---|
| N1 | `spec.md:224`, FR-031 vs FR-038, `contracts/skills.md` step 1 | The spec contradicts itself: the *Next is empty* edge case and FR-031 say the run "changes nothing", FR-038/SC-006 say every run writes a journal line (nothing-to-do included); precondition failures and an ineligible `--slug` end without a journal line in the skill/contract, which FR-038 does not allow. The skill follows the contract. | Align the spec text with the contract (list the no-journal exits: lock refused, precondition failed, ineligible slug). |
| N2 | `contracts/cli.md:34`; `backlog.py:1388-1389` | *Last triaged* is set on every `move` except to *Inbox* (e.g. *Next* → *Parked*), not "when the source is *Inbox* or the order of an ordered section changes". | Fix the contract or the code. |
| N3 | `contracts/cli.md:29` vs `backlog.py:1583-1584` | `new`: contract lists `--source`/`--who` as required; the code defaults them (`manual`, `agent`). | State the defaults in the contract. |
| N4 | `backlog.py:1635`, `:1626`, `:1598`, `:1559`, `:127-131`; skill uses bare `lock release` | Undocumented in `cli.md`: `remove --force`, `unblock --note`, `import-github --slug`, `--lock-dir`, `TANDEM_BACKLOG_NOW`, `lock release` without `--slug` (used by the nothing-to-do path). | Add to the contract. |
| N5 | `backlog.py:1232-1233` | `next --slug <unknown> --json` prints `refused: no item 'x'` (not JSON); the implement skill parses JSON. | Emit `{"slug": null, "refused": S, "reason": "no such item"}`. |
| N6 | `backlog.py:1323-1331`, `:1292-1298`, `create_item` | "Validates first" (`cli.md`, skill §0.2) is partial: `verify --commit ABCDEF1`, `set type=person-step` (no *Steps*), `set depends-on=<rejected or cyclic>` are written, then the check fails (exit 1, files left). | Validate commit format, type-specific headings, rejected/cyclic dependencies before writing; or soften the wording. |
| N7 | `backlog.py:1214` | `list --min-severity` crashes (`ValueError`) on an item whose header parses but has a non-numeric severity. | Skip or treat as -1. |
| N8 | `backlog.py:1436-1458` | `remove` rewrites dependents ("dependency X done in feature NNN") before `rmtree`; `rmtree` fails on a read-only file (traceback), leaving the item in place while its dependents already say it is done. | `rmtree(onerror=…)` clearing read-only, and delete the folder before touching dependents (or roll back). Measured: read-only `evidence/note.txt` → `PermissionError`, item and row stay. |
| N9 | `backlog.py:203-204` | A title ending in `\` renders as a broken link (`[… konec\](items/…)` — `\]` escapes the bracket); the tool still parses it. | Escape `\` in `esc_link_text` (and unescape nowhere — the cell is display only). |
| N10 | `backlog.py:780-782`, `:790-792` | Rules enforced but not in the contract: unknown `## ` headings are findings (e.g. `## Steps to reproduce`, `## Workaround`), and section order is enforced (from `data-model.md`, not `item-format.md`). | Add both to `contracts/item-format.md` or relax unknown headings. |
| N11 | `backlog.py:683-700` | Statuses / types are read from the legend, but `expected_section` knows only the built-in ones: a status added to the legend makes the `section` rule silent for that item. | Add a finding "status has no section rule" or fix the vocabulary in code. |
| N12 | `backlog.py:911-917` | `issue.md` is required iff `github#N`, but only one direction is checked (an `issue.md` on a non-github item passes); only its first line is validated. | Optional. |
| N13 | `backlog.py:857-858` | Git does not keep an empty `backlog/items/`; when the last item is removed, a fresh clone gives `layout: items/ folder missing` and the implement precondition (`TOTAL: 0`) fails. A `.gitkeep` would itself be a `layout` finding. | Treat a missing `items/` as empty. |
| N14 | `backlog.py:152-164` | CRLF files (this machine: `core.autocrlf=true`, `* text=auto`) are read correctly and rewritten as LF; git normalises, so no content diff. Measured, benign. | — |
| N15 | implement `SKILL.md` step 4 / `create-new-feature.sh:175` | The mandatory `before_specify` hook runs `git fetch --all --prune` (network; prunes remote-tracking refs). Not a push, and §0.4 forbids only "fetch-and-merge", but the run is not fully offline as "nothing leaves the machine" suggests. | Mention it in stop-rules §2.12. |
| N16 | implement `SKILL.md` steps 1–2 | A second run in the **same** working tree fails the precondition (not on `main`) before it can see the lock, so it ends `refused (precondition …)` instead of FR-039's "another run in progress (item, branch, age)". Also: because `start` happens on the branch, `main`'s *In progress* section never shows an autonomous run; only `lock status` does. | Run `BL lock status` first and report the holder in a precondition failure. |
| N17 | `contracts/skills.md` vs the rewritten implement skill; `tandem-backlog/SKILL.md:153` vs `:69-72` | `contracts/skills.md` still describes steps 1–8 and "`--dry-run` performs steps 1–3" (the skill's dry run stops after selection). Agent mode: §0.3 allows `update` only of items "you created in this session", §2.1 step 2 lets an agent extend another *Inbox* item's body — FR-014 lists only `verified`, `updated`, *Log*. | Update `contracts/skills.md`; align the agent-mode rule with FR-014 (or amend FR-014). |

---

## Walk-through of `/tandem-backlog-implement` (reviewed version)

| Path | Ends on `main` with | Item picked again? | Journal | Lock | Push |
|---|---|---|---|---|---|
| (a) success | FF to the branch: item removed, leftovers in *Inbox*, `closed` row | no (removed) | yes (via FF) | released after FF | none |
| (b) stop after the branch exists | WIP on the branch; `main`: item `blocked` + decision/person/split items + `blocked`/`split` row | no (blocked) | yes | released | none — but out-of-scope findings stay on the branch (S10); **the next run then trips M1** |
| (c) not reproduced | `verify` + `block` + `not-reproduced` row, one commit | no (blocked) | yes | released | none; closing such an item needs S14 |
| (d) nothing to do | one `nothing-to-do` row, one commit | — | yes | acquired (no slug) and released with bare `lock release` (works: slug `-`) | none |
| (e) lock held | nothing changed | — | none (FR-039) | not acquired | none; same-tree case reports a precondition instead (N16) |
| (f) FF failure | `main`: `block` + `blocked` row; branch: removal + `closed` row | no (blocked) | two contradicting rows after the manual merge (S11) | released | none |

Every command and option the skill names exists in `backlog.py`
(`next --json/--slug`, `lock acquire --slug`, `lock release [--slug]`,
`lock status`, `verify --note`, `block --reason`, `log`, `start --feature`,
`remove --feature`, `new --type/--who/--source/--related`, `run-log
--outcome/--slug/--feature/--branch/--inbox/--person/--note`, `check`).
The order "`speckit-specify` before `start`" works with the git extension
(the hook branches from the current `main` and carries the uncommitted
`verify` change; `start` then finds `specs/NNN-*`) — provided the numbers
agree (M1). The extension's commit hooks match `git-config.yml`
(after specify / clarify / plan / tasks / implement enabled, `git add .`).

## Verified as correct

- Atomic per-file writes (temp + `os.replace`); a leftover `*.tmp~` is
  reported by `layout`.
- Czech letters and emoji in titles, bodies and log lines survive every
  command; `|`, `[`, `]`, `: ` and inner backslashes in titles are escaped
  in the overview, parsed back to the right cell count, and the header keeps
  the raw title (value = text after the first `": "`). CRLF input is read;
  a BOM is a finding.
- `remove` can only delete the folder of a parsed item: `../…`, a
  differently cased slug and unknown slugs are refused; malformed items are
  refused by `set`, `move`, `block`, `verify`, `start`, `remove`.
- `set` refuses `status`/`updated`, unknown keys, values outside the
  legend and references to missing items before writing; title change keeps
  the slug and rewrites the body's first line; type/who changes relocate the
  row.
- `new` refuses an existing slug (naming it), a title without a slug, and
  invalid values without creating anything; `import-github` refuses an
  already imported issue (also one created by migration) and writes nothing
  on a network error.
- `next` implements FR-031 exactly (status `open`, who agent/both, type not
  decision/person-step, no `depends-on` still present); skipped rows are
  reported with reasons; JSON shapes match what the skill parses.
- Lock: `O_EXCL` creation under `git rev-parse --git-common-dir`, holder
  printed on refusal, `STALE` after 24 h, never released automatically,
  release only with matching slug or `--force`.
- All 18 rule ids of `cli.md` are implemented; section admission equals
  FR-013 with the contract's precedence (decision before person); the
  `derived` check renders with the same function as `sync`, so they cannot
  disagree; `sync` refuses when rows and items are not one-to-one; dangling
  rows and rows of malformed items are kept verbatim by every rewrite; free
  text between tables survives; a second table in a section blocks every
  changing command (no loss).
- Orphan recovery by `move` (reference.md §6) works (the new test
  `test_move_restores_orphan_row` and a manual run after the concurrency
  test).
- `tools/backlog/__pycache__/` is ignored by `.gitignore:10`, so running the
  tests does not dirty the tree for the implement precondition; `build/` is
  ignored too.
- The README's negative control holds: with the cycle rule disabled,
  `test_every_rule_is_detected` fails.

---

## Resolution (2026-10-17)

Code: `tools/backlog/backlog.py`; tests: `tools/backlog/test_backlog.py`
(55 tests); negative controls: `specs/242-backlog-system/probe/mutate.py`
(32 mutants — 31 caught; `first-link-wins` survives as an equivalent mutant:
escaping leaves exactly one real link per row, so first and last match
agree). Contracts, spec and both skills updated.

| # | Resolution |
|---|---|
| M1 | Implement skill step 4: the specify input carries `SPECIFY_FEATURE_DIRECTORY: specs/<BRANCH_NAME>`; the check is `ls -d specs/<BRANCH>`, a differently named folder is `git mv`-ed; stop-rule 8 reworded; quickstart V10 added; `contracts/skills.md` guarantee 5. |
| M2 | `render_table` keeps rows without an item link verbatim in every rewrite; `sync` refuses while `BACKLOG.md` has findings (test `test_m2_…`, seeded `hand-written-row`). |
| S1 | Row identity = the last `](items/<slug>/desc.md)` preceded by an even number of backslashes; link text escapes `\`, `[`, `]` (test `test_s1_…`). |
| S2 | Header values and reasons are refused with control characters before anything is written (`one_line`); log lines and journal cells are flattened; `value` reports control characters in a header; reference.md §6 sends `header` findings to `git restore` (tests `test_s2_…`, seeded `control-character`). |
| S3 | Every command writes `BACKLOG.md` once, after its items (`place_row` / `unplace_row` / `touch_triaged` in memory, one `save_overview`). |
| S4 | Unique temporary names (`mkstemp`); one-writer rule documented in `cli.md`, the management skill §0.2 and the spec edge case (git conflict: keep both rows, `sync`). No tool-level lock (not needed with the rule; recorded). |
| S5 | Not-UTF-8 files are findings (`header` / `overview` / `runs` / `github`), never a traceback (test `test_s5_…`, seeded `not-utf8`). |
| S6 | Headings inside fenced code blocks are ignored by every rule and by `log` (test `test_s6_…`). |
| S7 | Comments read page by page (`per_page=100`); a count different from the issue's refuses the import; *Problem* = the first non-heading paragraph, quoted (tests `test_all_comment_pages_and_heading_body`, `test_comment_count_mismatch_refused`). |
| S8 | Contract changed to the code's rule: moving never unblocks; the log says "still blocked: <reason>"; `unblock` is an operation of the management skill (test `test_s8_…`). |
| S9 | Leaving `parked` / `rejected` for any section (Inbox too) needs `--reason`; no `None` in logs (test `test_s9_…`). |
| S10 | Implement skill step 10.2a copies the items recorded on the branch to `main` and gives them *Inbox* rows (`move --section inbox` on an orphan). |
| S11 | Fast-forward failure: the reason carries the merge recipe (keep the branch's removal of the item, both journal rows); 10.1 and 10.2a skipped. |
| S12 | `lock update --slug --branch`, called in step 4 after `start` (test `test_s12_…`). |
| S13 | Management skill §0.2: no backslash on the command line; such texts go into the body with the Edit tool. `contracts/skills.md` guarantee 4. |
| S14 | Operations `unblock` and `close` (§2.12, §2.13); tool `remove <slug> --reason` closes without a feature, refused for `in-progress`, dependents logged (test `test_s14_…`). |
| S15 | 20 new tests and 11 sub-rule seeds (`SEEDED_MORE`); mutation score 31 / 32 (above). |
| N1 | Spec FR-038 lists the no-journal exits; the *Next is empty* edge case says "only its journal line". |
| N2 | Contract: *Last triaged* on every move except to *Inbox* (the code's behaviour). |
| N3 | Contract states the defaults of `new`. |
| N4 | Contract documents `remove --force`, `remove --reason`, `unblock --note`, `import-github --slug`, `lock update`, `lock release` without `--slug`, `--lock-dir`, `TANDEM_BACKLOG_NOW`. |
| N5 | `next --slug <unknown> --json` prints JSON (test `test_n5_…`). |
| N6 | `verify --commit` format, rejected / cyclic `depends-on` validated before writing; a type change inserts the type's sections with placeholders and says so (tests `test_n6_…`). |
| N7 | `list --min-severity` skips a non-numeric severity. |
| N8 | `remove` deletes the folder first (read-only files included), then touches dependents (test `test_n8_…`). |
| N9 | `\` escaped in link text (test `test_n9_…`); the real backlog re-synced (one title with `\b`). |
| N10 | `contracts/item-format.md`: allowed headings, order, fences, *Steps* rule. |
| N11 | A legend status without a section rule is a `value` finding. |
| N12 | Not changed (optional). |
| N13 | A missing `items/` is an empty backlog. |
| N14 | — (benign, measured). |
| N15 | stop-rules §2.12 mentions the extension's `git fetch --all --prune`. |
| N16 | Step 1 reads `lock status` first and reports the holder before the other preconditions. |
| N17 | `contracts/skills.md` rewritten as guarantees of the current skills; agent mode aligned with FR-014 (agents change only items they created in the session). |
