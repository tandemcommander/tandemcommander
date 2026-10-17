---
name: "tandem-backlog-implement"
description: "Take ONE eligible item from the Tandem Commander backlog (the first eligible row of Next, or a named slug) and implement it autonomously through the full Spec Kit flow (specify, clarify, plan, tasks, analyze, implement), then close it, or stop with a recorded reason. One item per run, then end. Use only when the maintainer asks to run or implement a backlog item."
argument-hint: "[<slug>] [--dry-run]"
compatibility: "Requires backlog/, tools/backlog/backlog.py, the Spec Kit skills and its git extension (feature 242)"
user-invocable: true
disable-model-invocation: false
---

## User Input

```text
$ARGUMENTS
```

Arguments: an optional item slug; an optional `--dry-run`. Nothing else.
The maintainer may write in Czech; everything written into the repository
is English.

---

## 0. Contract of a run

1. **Exactly one item, then end.** Never start a second item, not even
   after a quick finish or a stop.
2. **Read [stop-rules.md](stop-rules.md) completely before step 1.** It
   decides every question (§1), the project rules of the work (§2) and when
   to stop (§3).
3. **Unattended**: nobody answers. Never use the question tool, never wait
   for input. Questions of Spec Kit skills: stop-rules §1. Prompts of skills
   ("proceed?", optional hooks): stop-rules §1, last table.
4. **Never**: push, merge from the remote, tag, publish a release, post to
   GitHub, submit to winget, reorder `BACKLOG.md`, change another item's
   status, delete a branch, force anything (`--force`, `reset --hard`,
   `checkout -f`, `clean`). The only merge is the fast-forward of step 9.
5. **Every path ends** with the lock released (if this run acquired it),
   the current branch `main` (except a failed precondition, where nothing
   changed), and the final message of §11.
6. **Tools**:
   - **Bash** for git, the backlog tool and Python checks, always from the
     repository root. Throughout: `BL` = `python tools/backlog/backlog.py`.
   - **PowerShell** for `build.cmd`, `saltests.exe` and GUI probes (Bash
     mangles their backslash paths).
   - **Skill** for the Spec Kit skills; **Agent** for the independent review.
7. **Never put item text on a command line.** *Problem*, *Evidence* and the
   rest contain backticks, `$` and backslashes; inside a double-quoted shell
   argument Bash would run backticked text as commands (measured: an
   *Evidence* path was executed as a script). On command lines use only
   slugs, numbers, branch names and short texts you write yourself, in
   **single quotes**, without backslashes. Longer texts go into files with
   the editor.
8. **Exit code 1 of `BL` has two forms.** Output starting with `refused:` →
   nothing was written; fix the cause and repeat. Output containing
   `check after the change found problems:` → **the change was written**;
   never repeat the command; fix the listed findings
   (`.claude/skills/tandem-backlog/reference.md` §6).
9. **Every `BL new` of a run** (findings, leftovers, person steps,
   decisions, split parts) follows `/tandem-backlog` `SKILL.md` §0.2
   (quoting, no backslash on the command line) and §2.1 steps 2–7 (look for
   an existing item, decide the fields by its `reference.md` §3, title and
   slug, create, complete the body with the editor, then
   `grep -n '(to be written)' backlog/items/<slug>/desc.md` → no output).
   Count every item you add in `INBOX`.
10. **Commits**: every commit of the run is
    `git commit -m '<subject>' -m '<body, optional>' -m '<the attribution lines the session's instructions give for commits>'`.
    The templates below give the subject only. English.

Values to remember once known: `SLUG`, `TITLE`, `HEAD0` (short commit of
`main` at the start), `SHORT` (2–4 words of the slug, hyphenated), `NNN`,
`BRANCH`, `INBOX` (number of items added), `PERSON` (one line of what is
owed to a person, or `-`).

---

## 1. Preconditions — change nothing if any fails

Also for `--dry-run`.

```text
BL lock status                      → "free", or a holder
git rev-parse --abbrev-ref HEAD     → must print: main
git status --porcelain              → must print nothing
BL check                            → last line must be: TOTAL: 0
git rev-parse --short HEAD          → HEAD0
```

- A holder → end with outcome `refused (another run in progress: <the
  printed holder line>)`, also when the other checks would fail. A `STALE`
  holder: say so — only the maintainer releases it
  (`BL lock release --force`).
- Any other failure → end with `refused (precondition: <which, with the
  printed output>)`.

No lock, no journal row, no commit in either case.

## 2. Select the item

```text
BL next --json                       (no slug given)
BL next --slug <slug> --json         (slug given)
```

Output: `{"slug": <slug or null>, "skipped": [{"slug": …, "reason": …}, …]}`;
with `--slug` and an ineligible or unknown item: exit 1 and
`{"slug": null, "refused": …, "reason": …}`.

| Result | Do |
|---|---|
| `--slug` refused | end: `refused (not eligible: <reason>)`; nothing changed |
| `"slug": null`, `--dry-run` | end with the dry-run message below |
| `"slug": null` | `BL lock acquire` (exit 1 → end `refused (another run in progress: <holder>)`) → `BL run-log --outcome nothing-to-do --note '<skipped as slug=reason; …, at most 200 characters>'` → `BL check` (TOTAL: 0) → `git add backlog/RUNS.md` → commit `backlog: run found nothing to do` → `BL lock release` → end `nothing-to-do` |
| a slug | `SLUG` = it; read `backlog/items/<SLUG>/desc.md`; `TITLE` = its title |

**Dry run** (no lock, no change): read the item and plan step 3, then end
with exactly:

```text
Outcome: dry-run
Item: <SLUG> - <TITLE> (Next #<position>)        or: Item: - (nothing eligible)
Skipped: <slug: reason; …>                        or: Skipped: -
Would check: <one line: the sites / probe / test step 3 would use>
Lock: <the output of BL lock status>
```

Not a dry run, a slug chosen:

```text
BL lock acquire --slug <SLUG>
```

Exit 1 → end `refused (another run in progress: <holder>)`; nothing
changed. From here on, every path runs `BL lock release --slug <SLUG>`
before ending.

## 3. Measure first (on `main`, before any feature exists)

Read the whole item: `desc.md`, `issue.md`, files in `evidence/`, the
*Problem* of every `related` item. If its *Log* names an earlier branch of
a stopped run, read that run's record:
`git show <branch>:specs/<branch>/fix-log.md` (and its `closing-report.md`
if any) — continue from what it found; do not repeat a measurement it
recorded unless HEAD changed the site.

Then establish **at HEAD** whether the defect or gap still exists:

1. Locate every site named in *Evidence*. Line numbers move: search by
   function name or quoted text with the Grep tool, not by line.
2. Check the defect is reachable: trace the caller chain from a user action
   to the site, with the default configuration unless the item says
   otherwise.
3. When reproduction is feasible in the run (a unit test, `saltests`, an
   existing or small hidden-desktop probe — stop-rules §2.7), reproduce it
   on the current build. Note exactly what you ran and what you saw; it
   goes into the specify input and later into `fix-log.md`.

| Finding | Do |
|---|---|
| still present | `BL verify <SLUG> --note '<how confirmed, short>'` (it is committed later on the feature branch). Continue with step 4 |
| not present | `BL verify <SLUG> --note 'not reproduced: <short>'` → `BL block <SLUG> --reason 'not reproduced at <HEAD0>: <one line>'` → `BL run-log --outcome not-reproduced --slug <SLUG> --note '<one line>'` → `BL check` (TOTAL: 0) → `git add backlog` → commit `backlog: <SLUG> not reproduced at <HEAD0>` → `BL lock release --slug <SLUG>` → end `not-reproduced` |
| needs a person to tell | stop (step 10, no branch): a `person-step` item with the exact check; reason `needs a person to confirm: <what>` |
| larger than one feature | stop (step 10, no branch) with outcome `split`: one new item per part |
| a maintainer-owned question (stop-rules §1) | stop (step 10, no branch): a `decision` item |

## 4. Specify — the branch, the number, the spec folder

**4.1 Learn the branch name in advance** (read-only; the script only
computes it with `--dry-run`):

```text
bash .specify/extensions/git/scripts/bash/create-new-feature.sh --json --dry-run --short-name '<SHORT>' 'Backlog item <SLUG>'
```

Output `{"BRANCH_NAME": "...", "FEATURE_NUM": "...", "DRY_RUN": true}`.
`BRANCH` = BRANCH_NAME, `NNN` = FEATURE_NUM. (The number counts `specs/`
and all branches, also unmerged branches of stopped runs.)

**4.2 Write the specify input** with the editor into the file
`<scratchpad>/specify-input-<SLUG>.md` (the session's scratchpad folder),
exactly this shape:

```text
Backlog item <SLUG> (backlog/items/<SLUG>/desc.md) - implement exactly what it describes.
GIT_BRANCH_NAME: <BRANCH>
SPECIFY_FEATURE_DIRECTORY: specs/<BRANCH>
Hook rule: the before_specify hook must run create-new-feature.sh with the environment
variable GIT_BRANCH_NAME=<BRANCH> and with the description 'Backlog item <SLUG>' in
single quotes - never with the text below.
Title: <TITLE>
Problem: <Problem section, verbatim>
Evidence: <Evidence section, verbatim>
Expected: <Expected section, verbatim>
Approach: <Approach section or "none given">
Notes: <Notes section or "none">
Related items: <slug: first sentence of Problem; …> or none
Issue: <for github#N: number, title and the first paragraph of issue.md> or none
Measured at <HEAD0>: <the finding of step 3, with what you ran>
```

**4.3 Invoke** the Skill `speckit-specify` with the content of that file as
the argument. Inside it:

- its mandatory `before_specify` hook invokes `speckit-git-feature`: run
  the script exactly as the *Hook rule* line says —
  `GIT_BRANCH_NAME='<BRANCH>' bash .specify/extensions/git/scripts/bash/create-new-feature.sh --json --short-name '<SHORT>' 'Backlog item <SLUG>'`
  (it also runs `git fetch --all --prune`, which only reads the remote);
- the spec folder is the explicit `SPECIFY_FEATURE_DIRECTORY`
  (`specs/<BRANCH>`), used as-is;
- `[NEEDS CLARIFICATION]` questions: answer by stop-rules §1
  (maintainer-owned → step 10);
- the optional hook `/speckit-git-commit` at its end: accept (§5).

**4.4 Check, in this order:**

1. `git rev-parse --abbrev-ref HEAD` must print `<BRANCH>`. Otherwise →
   step 10 with reason `specify did not create the branch <BRANCH>`.
2. `ls -d specs/<BRANCH>` must exist. If not, and specify made another
   `specs/NNN-*` folder: `git mv specs/<that> specs/<BRANCH>`, edit
   `.specify/feature.json` to `{"feature_directory": "specs/<BRANCH>"}`.
   If there is no folder at all → step 10, reason `specify did not create
   specs/<BRANCH>`.

**4.5 Start:**

```text
BL start <SLUG> --feature <NNN>
BL lock update --slug <SLUG> --branch <BRANCH>
```

Add to the spec's `**Input**` line: `From backlog item <SLUG>.` Then
`git add -A` and commit `[<NNN>] start: backlog item <SLUG>` (skip if
nothing is staged).

## 5. The rest of the Spec Kit flow

Run in this order, each with the Skill tool, each to its end:

| Skill | How |
|---|---|
| `speckit-clarify` | For each question it would ask: apply stop-rules §1 steps 1–4 **in order** (maintainer-owned → step 10 with a `decision` item; the item or a rule answers → that; else its Recommended / Suggested option; else the conservative one). Integrate the answer as the skill describes and write the Clarifications bullet exactly as stop-rules §1 says. Never wait for input. |
| `speckit-plan` | as written |
| `speckit-tasks` | as written |
| `speckit-analyze` | Fix every CRITICAL and HIGH finding in `spec.md` / `plan.md` / `tasks.md`, then run it once more. After the second run: CRITICAL left → step 10 (stop-rules §3 #9); HIGH left → if it concerns a requirement of the item, step 10 likewise; otherwise record in `fix-log.md` why it is accepted and continue. MEDIUM / LOW: fix if cheap, else record. |
| `speckit-implement` | "Some checklists are incomplete. Proceed?" → do not proceed: complete them by fixing the artifacts, then continue. Follow stop-rules §2 throughout. Mark tasks `[X]` as they are done. |

**Optional hooks**: whenever a Spec Kit skill prints an *Optional Hook*
`/speckit-git-commit` with an event (e.g. `after_plan`), invoke the Skill
`speckit-git-commit` with that event name as the argument. It commits only
the events enabled in `.specify/extensions/git/git-config.yml` (after
specify, clarify, plan, tasks, implement) with `git add .` — safe, the tree
was clean at the start.

**Findings outside the item's scope**: never fix them here. Record each as
a new item (§0.9) with `--source measure:<NNN>` (or `review:<NNN>` from the
review).

## 6. Verify the feature

All must hold before step 7 (command → expected result):

| Check | Command | Expected |
|---|---|---|
| tasks | read `specs/<BRANCH>/tasks.md` | every task `[X]`, or the open ones explained in `fix-log.md` as owed to a person |
| encoding guard | Bash: `python tools/check_encoding.py --strict` | last line `TOTAL: 0 finding(s)`, exit 0 |
| build | PowerShell: `.\build.cmd` (`.\build.cmd full` when UI strings, language files, resources or plug-in lists changed) | a line `BUILD SUCCEEDED`, exit 0 |
| unit rules | PowerShell: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` (when the core or `src/common/` changed; the build folder is `$env:OPENSAL_BUILD_DIR` when set) | last line `saltests: <n> checks, 0 failed`, exit 0 |
| probes | stop-rules §2.7 | every row PASS or recorded NOT DRIVEN |
| the item | the measurement of step 3, repeated | the defect is gone |
| record | `specs/<BRANCH>/fix-log.md` | before / after, the commands and their results |

UI strings added or removed: the two-stage `.slt` refresh is **not** done
by a run → step 10 (stop-rules §3 #2) unless the item says how.

A check that still fails after three honest fix attempts (each recorded in
`fix-log.md`) → step 10.

## 7. Independent review

Launch one Agent (subagent type `general-purpose`) with this prompt,
filled in:

```text
Independent refute-first review of feature <NNN> in E:\Projects\tandemcommander
(branch <BRANCH>; diff: git diff main...<BRANCH>). It implements backlog item
<SLUG>: <TITLE>. Spec: specs/<BRANCH>/spec.md; fix-log: specs/<BRANCH>/fix-log.md.
Assume it is wrong until shown otherwise. Check: does it fix exactly what the
item describes (re-run the measurement in the fix-log); can it lose user data
(CLAUDE.md "Never lose the user's data"); regressions in callers (enumerate them
yourself); the standing rules of CLAUDE.md (UTF-8 names, never cut a path,
refuse instead); tests and probes really prove the claims (try a negative
control). Do not edit files. Report MUST / SHOULD / NOTE findings with file:line
and a reproduction.
```

- MUST findings: fix them, repeat the affected checks of step 6, launch a
  fresh review with the same prompt plus `Previous findings: <list>`.
- A second review with MUST findings → step 10 (stop-rules §3 #3).
- SHOULD findings: fix those inside the item's scope; others → new items
  (§0.9, `review:<NNN>`).
- Record both reviews in `fix-log.md`, section *Review*.

## 8. Close the item (on the feature branch)

1. A `github#N` item: first copy `issue.md` and `reply.md` into
   `specs/<BRANCH>/`, write the draft answer into the copied `reply.md`
   (what was fixed, in which feature, the limits), and set `PERSON` to
   include `answer and close GitHub issue #N (draft in specs/<BRANCH>/reply.md)`.
2. `BL remove <SLUG> --feature <NNN>` (deletes the item and its row;
   removes it from other items' `related` / `depends-on`, logging there).
3. Leftovers and person steps → new items (§0.9), source `leftover:<NNN>`
   (person checks: `--type person-step --who person`, *Steps* filled);
   extend `PERSON` with one line naming them.
4. Append to the end of `specs/FEATURE-HISTORY.md` an entry in the style of
   the last entries:

   ```text
   - <BRANCH>: <what was wrong, in the user's terms> - now <what it does>.
     <the traps met / limits left>. From backlog item `<SLUG>`. Probe
     `<name>` <before> -> <after>; <reviews>.
   ```

   In its *Index by area*, add `<NNN>` to the row whose title fits the
   feature; if no row fits, leave the index unchanged.
5. `CHANGELOG.md`, when the change is user-visible: an entry at the top of
   the section whose heading ends `— unreleased` — bold symptom, `(feature
   <NNN>)`, what it does now, the limits that remain — in the style of the
   entries around it. No such section → do not create one (versions are
   the maintainer's): put the entry text into `closing-report.md` and add
   `add the CHANGELOG entry from specs/<BRANCH>/closing-report.md` to
   `PERSON`.
6. Write `specs/<BRANCH>/closing-report.md`:

   ```text
   # Closing report - <BRANCH>
   Backlog item: <SLUG> - <TITLE>
   Outcome: closed
   ## What changed
   ## Measurements (before / after, commands)
   ## Checks (encoding guard, build, saltests, probes - with numbers)
   ## Reviews (findings and what was done)
   ## Owed to a person (with the new person-step items)
   ## New Inbox items (slug - title)
   ```

7. `CLAUDE.md`: only if the feature produced a rule that must change how
   future work is done — one line in *Standing rules* with the feature
   number. Usually nothing.
8. Journal and checks:

   ```text
   BL run-log --outcome closed --slug <SLUG> --feature <NNN> --branch <BRANCH> --inbox <INBOX> --person '<PERSON>' --note '<one line: what was fixed>'
   BL check                                   → TOTAL: 0
   python tools/check_encoding.py --strict    → TOTAL: 0 finding(s)
   ```

9. `git add -A`; `git status --short` must list only files of this feature
   (its sources, `specs/<BRANCH>/`, `backlog/`, `specs/FEATURE-HISTORY.md`,
   `CHANGELOG.md`, maybe `CLAUDE.md`); anything else → `git restore
   --staged <file>` and name it in the closing report. Commit
   `[<NNN>] <the user-visible change, in the project's style>` with a body
   of 2–5 lines (what was wrong, what it does now, the probe numbers).

## 9. Fast-forward `main`

```text
git checkout main
git merge --ff-only <BRANCH>
```

- Success → `BL lock release --slug <SLUG>` → end `closed`.
- Failure (someone committed to `main` during the run) → stay on `main`,
  go to step 10 with exactly this reason, and skip 10.1 and 10.2a:

  ```text
  fast-forward failed - finished work on <BRANCH>; merge by hand: git merge <BRANCH>; on conflicts: git rm backlog/items/<SLUG>/desc.md, keep both RUNS.md rows, take the branch's backlog/BACKLOG.md, then python tools/backlog/backlog.py sync and check
  ```

  Do not rebase or merge yourself.

## 10. Stop

Whenever stop-rules §3 or a step above says "step 10".

1. A feature branch exists and you are on it: record in
   `specs/<BRANCH>/fix-log.md` what was done and why the run stops; then
   `git add -A` and commit `[<NNN>] stopped: <reason>` (skip if nothing to
   commit).
2. `git checkout main`. (On `main` the item is still `open` without a
   feature number — the start happened on the branch.)

   2a. **Bring the items recorded on the branch to `main`.** List them:

   ```text
   git diff --name-only --diff-filter=A main...<BRANCH> -- 'backlog/items/*/desc.md'
   ```

   First copy **every** listed folder except `<SLUG>`
   (`git checkout <BRANCH> -- backlog/items/<slug>` for each), **then** run
   `BL move <slug> --section inbox` for each (it adds the missing row).
   Until the last move, `orphan` findings that name a listed slug are
   expected (exit 1 of the second form, §0.8); after the last move
   `BL check` must print `TOTAL: 0`.
3. Record what the maintainer must do, as new items (§0.9):
   - a maintainer-owned question → `--type decision`, *Question* /
     *Options* (with consequences) / *Recommendation*, `--related <SLUG>`;
   - needs a person → `--type person-step --who person`, *Steps*;
   - too large → one item per part, each one feature's worth,
     `--related <SLUG>`.
   Source `measure:<NNN>`, or `manual` when no number exists yet.
4. `BL block <SLUG> --reason '<reason> (feature <NNN>, branch <BRANCH>)'`
   (without a branch: just the reason). A split also gets
   `BL log <SLUG> 'split into: <slugs>'`.
5. `BL run-log --outcome <blocked|split> --slug <SLUG> [--feature <NNN> --branch <BRANCH>] --inbox <INBOX> --person '<PERSON>' --note '<reason, short>'`
6. `BL check` → `TOTAL: 0`; `git add backlog`; commit
   `backlog: <SLUG> blocked (<NNN>)` (no branch: `backlog: <SLUG> blocked before specify`).
7. **No branch exists but specify ran** (it failed before the branch was
   made): `git status --porcelain` must be empty now — if specify left a
   `specs/<folder>` or a changed `.specify/feature.json` on `main`, remove
   them (`git restore .specify/feature.json`; delete the folder) and name
   them in the final message.
8. `BL lock release --slug <SLUG>`; end `blocked` or `split`.

A stop before step 4 (no branch): skip 10.1, 10.2 and 10.2a; leave `NNN` /
`BRANCH` out of the reason, the journal and the commit message.

If a step of 10 itself fails: do the remaining steps you can, always
release the lock, and say exactly what is left in the final message.

## 11. Final message (every path)

```text
Outcome: closed | blocked | split | not-reproduced | nothing-to-do | dry-run | refused (<why>)
Item: <SLUG> - <TITLE>                    (or -)
Feature / branch: <NNN> / <BRANCH>        (or -)
Reason: <for blocked / split / not-reproduced / refused, one or two lines>  (or -)
Owed to a person: <PERSON>                (or -)
New Inbox items: <slug - title; …>        (or -)
Report: specs/<BRANCH>/closing-report.md  (or -)
Journal: backlog/RUNS.md (last row)       (or "no journal row: <why>")
Lock: released | not acquired
main: <short HEAD of main> - nothing pushed
```

The dry run ends with its own five-line message (step 2) instead.
