# Review 2: the skills of feature 242 (refute-first)

**Date**: 2026-10-17 · **Reviewer**: second independent agent · **Mode**: this
report is the only repository file written. Every operation ran on a copy
(`backlog/`, `tools/backlog/` and `.specify/` copied into
`%TEMP%\…\scratchpad\rv2`, `git init`, commands run exactly as the skills
write them). One demonstration (M1) was run by mistake with the repository
as the working folder. It executed `src/fileswn7.cpp` as a shell script,
which failed at line 17 with a syntax error. `git status --porcelain` was
the same before and after (34 lines), so nothing changed.

**Reviewed versions**

| File | sha256 (12) |
|---|---|
| `.claude/skills/tandem-backlog/SKILL.md` | `3c19508500bd` |
| `.claude/skills/tandem-backlog/reference.md` | `cbc1fbf9977f` |
| `.claude/skills/tandem-backlog-implement/SKILL.md` | `27b5d21ee11c` |
| `.claude/skills/tandem-backlog-implement/stop-rules.md` | `40a8a890f040` |
| `tools/backlog/backlog.py` | `c9d7f107dc69` |
| `contracts/cli.md` / `contracts/skills.md` | `a96b51778576` / `283f254634b7` |

On the real repository (read-only):
- `python -m unittest tools/backlog/test_backlog.py` → `Ran 55 tests … OK`.
- `python tools/backlog/backlog.py check` → `TOTAL: 0`, exit 0.

Running the tests leaves the tree unchanged.

Counts: **2 MUST · 20 SHOULD · 18 NOTE**.

Abbreviations: **B** = `tandem-backlog/SKILL.md`, **R** = `tandem-backlog/reference.md`,
**I** = `tandem-backlog-implement/SKILL.md`, **SR** = `tandem-backlog-implement/stop-rules.md`.

---

## Findings

### MUST

| # | Where | Problem | How shown | Suggested wording |
|---|---|---|---|---|
| M1 | I:132-160 (step 4), `.claude/skills/speckit-git-feature/SKILL.md` *Execution* | **Item text runs as shell code.** Step 4 makes the whole item text the argument of `speckit-specify`: *Problem*, *Evidence* and *Expected* go in word for word, and they are full of backticks and `$`. The mandatory hook passes that argument as `<feature description>`, and `speckit-git-feature` writes it as `create-new-feature.sh --json --short-name "<short-name>" "<feature description>"`, in **double quotes**. In Bash, every backtick span is then run as a command and every `$X` is expanded. Backticked file paths are typical of *Evidence* (``` `src/fileswn7.cpp` ~1960 ```), and Bash falls back to running such a file as a shell script. This happens in an unattended run before any review. | `D="Evidence: \`src/fileswn7.cpp\` ~1960; \`echo INJECTED\` at \$HOME"; eval "printf '%s\n' \"$D\""` → Bash executed `src/fileswn7.cpp` line by line (`line 17: syntax error near unexpected token '('`), then printed `Evidence:  ~1960; INJECTED at /c/Users/pavel`. | Add to step 4, after "Invoke the Skill `speckit-specify`": "**When the `before_specify` hook runs `create-new-feature.sh`, pass `--short-name '<short name>'` and as the description only `'Backlog item <SLUG>'`, both in single quotes. Never put the item text on a command line** (it contains backticks and `$`). The same applies to every Bash command of the run: item text goes into files with the editor, never into a double-quoted argument." |
| M2 | B:342-354 (§2.9 *decide*, "do not do it"), B:356-368 (§2.10 *reject*), R:224-226 | **Rejecting an item that others depend on fails the check, and no rule says what to do next.** `move --section rejected` writes the item, then exits 1 with `ref: depends-on '<slug>', which is rejected and never done` on every dependent. §2.9 lists the dependents only in step 3, after the move. §0.5 then requires `TOTAL: 0`, and the only fix in §6 is "`BL set <dependent> depends-on=…`", a change to another item that the skill does not authorise. This is the common case, not an edge case: R §4 says "items that depend on a decision wait for it". Semantically, an answered decision is *done*, not "decided not to do". | Copy: created `decide-d` (decision) and `work-w` (`--depends-on decide-d`). `BL move decide-d --section rejected --reason 'maintainer 2026-10-17: keep as is'` → exit 1, `TOTAL: 1`. `BL remove decide-d --reason …` → exit 0, `work-w` gets `depends-on: []` and a log line. | §2.9: make step 3 the **first** step. Replace the three outcomes with: "**do the work** → (as now); **answered, nothing to change** / **do not do it** → `BL remove <slug> --reason 'decided YYYY-MM-DD: <decision>; maintainer'` (the decision is done; dependents are logged and may start). Then ask the maintainer about each dependent from step 1: keep it, or reject it (`/tandem-backlog reject`); **later** → `BL move <slug> --section parked --reason '<why later; maintainer YYYY-MM-DD>'`." §2.10 *reject*, new step 1: "`grep -l 'depends-on: .*<slug>' backlog/items/*/desc.md`. If any item is listed, do not reject yet. Ask the maintainer, per dependent: reject it too, or drop the dependency (`BL set <dep> depends-on=<rest> --log 'dependency <slug> rejected'`). Do that first, then reject." |

### SHOULD

| # | Where | Problem | How shown | Suggested wording |
|---|---|---|---|---|
| S1 | I:148-152 | **Placeholder whose value is unknown at that point.** The `SPECIFY_FEATURE_DIRECTORY: specs/<the BRANCH_NAME printed by the before_specify hook>` line must be written *before* `speckit-specify` is invoked, but the hook prints `BRANCH_NAME` only *inside* specify. Taken literally, specify uses the value "as-is" (`speckit-specify/SKILL.md:87`), and here that value is the placeholder text. | Reading. `create-new-feature.sh --json --dry-run --short-name x 'x'` gives the number in advance: `{"BRANCH_NAME":"243-next-one","FEATURE_NUM":"243","DRY_RUN":true}`, measured after a stopped `242-…` branch with `specs/` only up to 241. | "Before invoking specify, run `bash .specify/extensions/git/scripts/bash/create-new-feature.sh --json --dry-run --short-name '<short>' 'Backlog item <SLUG>'` and take `BRANCH_NAME`. Append two lines to the input: `GIT_BRANCH_NAME: <BRANCH_NAME>` and `SPECIFY_FEATURE_DIRECTORY: specs/<BRANCH_NAME>`. Both skills use an explicit value as-is, so branch and folder are known before specify starts. After specify, check that the branch is `<BRANCH_NAME>`." |
| S2 | I:171-187 | **Step 4 is out of order.** The check block runs `BL start` and `lock update` right after the two checks. What to do when a check fails (rename the folder, or stop) is said only in the two paragraphs *after* the block. Someone executing it top-down starts the item before knowing whether the folder is right. | Reading. | Replace with numbered sub-steps: "4.1 `git rev-parse --abbrev-ref HEAD`; if it is not `<BRANCH>` → stop (step 10), reason `specify did not create the feature`. 4.2 `ls -d specs/<BRANCH>`; if it is missing and specify made another `specs/NNN-*` folder, `git mv` it to `specs/<BRANCH>` and correct `.specify/feature.json`; if there is no folder → stop as in 4.1. 4.3 `BL start <SLUG> --feature <NNN>`. 4.4 `BL lock update --slug <SLUG> --branch <BRANCH>`. 4.5 *Input* line; commit." |
| S3 | I:186-187, I:365-366 | **A stop without a branch leaves `main` dirty.** If the hook created no branch but specify wrote `specs/NNN-*` and `.specify/feature.json` (or the step 3 `verify` change exists), step 10 skips 10.1 and commits only `backlog`. The untracked folder and the modified `feature.json` stay behind. The next run then fails the `git status --porcelain` precondition, and so does every run after it. | Reading. Specify always creates the folder ("never by the hook"); the hook's failure paths exit before checkout. | Add to step 10, "A stop before a branch exists": "After 10.6, `git status --porcelain` must be empty. Revert what specify left on `main`: `git restore .specify/feature.json` and delete the `specs/<folder>` it created (name both in the final message)." |
| S4 | B:47-51, B:197-198, R:290; I:47-48 | **Exit 1 has two meanings, and the skills do not tell them apart.** "Refused, nothing written" and "**written**, the check afterwards found problems" both exit 1 (`cli.md:16`: "files stay as written"). The skills only say "read `refused:` and correct". After a finding that was already there, `new` writes the item and exits 1. If the agent repeats the command, it gets `already exists`, and R §6 then advises `--slug <other-slug>`, which makes a **duplicate**. The management skill also never checks before an operation, so findings already in the tree turn up here. | Copy: stray `items/stray-folder` → `new --title 'Another finding' …` printed the slug, then `check after the change found problems: … desc-missing`, exit 1. The folder exists. The same `new` again → `refused: item 'another-finding' already exists`. | B §0.2 and I §0.6: "Exit 1 has two forms. Output starting with **`refused:`** → nothing was written; fix the cause and repeat. Output containing **`check after the change found problems:`** → **the change was written**; never repeat the command; fix the listed findings (R §6)." B §0.5, new step 0: "Before a changing operation, run `BL check`. If it is not `TOTAL: 0`, fix it first (maintainer mode), or report it and stop (agent mode)." |
| S5 | B:356-368, B:397-402, B:406-410 | **Not every report has a fixed format.** *park*, *reject*, *reopen* (§2.10) and *check* (§2.11) have no report line. §3 *Final report (always)* gives loose bullets, and it is not said whether §3 replaces the per-operation *Report:* line or comes on top of it. | Reading. | §2.10: "**Report:** `<slug>: <old section> → Parked \| Rejected \| <section> #<p> — <reason>.`" §2.11: "**Report:** one line per finding `<rule> <slug>: <fix applied \| needs the maintainer: …>`, then `BL check: TOTAL: <n>`." §3: "The report is the operation's *Report:* line(s), then the line `BL check: TOTAL: 0` (or the findings that remain), then, in agent mode, `New items wait in Inbox for the maintainer's triage.` Nothing else." |
| S6 | B:68-71, B:116-136; R:241-243, R:263 | **There is no `block` operation.** §0.2 lists `block` among the commands the skill uses, and R §4 tells the maintainer to set *blocked* ("waits for an external PR …"). But §1 maps no words to it, and no section describes it. "Zablokuj X, čeká na server" ("block X, it waits for the server") would end at "cannot determine the operation", or be done by guessing. | Reading. | Add a row to §1: "`block` \| block, waits for (zablokuj, čeká na)". Add §2.14 *block* (maintainer mode): "`BL block <slug> --reason '<what it waits for>; maintainer YYYY-MM-DD'` (only an `open` item; the row stays). **Report:** `<slug>: blocked — <reason>.`" |
| S7 | B:277-282 (§2.5 step 4), B:346-349 (§2.9) | **`set type=` leaves placeholders that pass the check.** `BL set … type=person-step` adds `## Steps` with `- [ ] (to be written)` (and `type=decision` adds three placeholders); the check passes. Triage moves such an item on, and *Person steps* then holds a step with no content. When §2.9 converts a decision into a bug, *Question* / *Options* / *Recommendation* stay in the bug's body (the contract calls them "decision only"), and the skill says nothing about them. | Copy: `set packing-… type=person-step` → `added the sections Steps with placeholders - write them`; `move --section person` → exit 0, `check` → `TOTAL: 0`, placeholder still there. `set decide-something type=bug` → exit 0, the decision sections remain. | §2.5 step 4 and §2.9: "After a `set type=…` that prints `added the sections … with placeholders`, write those sections with the Edit tool (*Steps* from the maintainer's answer, one `- [ ]` line per check). Then `grep -n '(to be written)' backlog/items/<slug>/desc.md` must print nothing. When a decision becomes work, keep *Question* / *Options* / *Recommendation* as the record of the decision." (Or delete them; either way, choose one rule.) |
| S8 | B:336 vs B:83-86; B:110-111 | **Agent mode contradicts itself.** §2.8 row 2 ("Edit *Evidence*, then `BL verify`") edits the body of an item the agent did not create, which §0.3 forbids (FR-014). §0.5 also requires every operation to end at `TOTAL: 0` and points to R §6, but most §6 fixes (`move`, `set`, deleting rows) are forbidden in agent mode. | Reading. | §2.8 row 2: "maintainer mode or own item: Edit *Evidence* …; **agent mode**: `BL log <slug> 'evidence moved: <old> → <new file:line at commit>'`, then `BL verify …`." §0.5: "Agent mode: fix only findings on items you created in this session; report every other finding and stop." |
| S9 | B:219-233 (§2.2) | **`import-github` cannot be done as written.** (a) "Read the issue first" names no command. `gh` is not installed on this machine, the tool has no read-only fetch, and the following sentence ("if you cannot tell before reading …") contradicts it. (b) The tool sets the title to the issue title word for word; the measured one has **118** characters against the ≤ 80 rule of R §2, and §2.2 never corrects it. (c) *Expected* stays `(to be written)`, and nothing checks for it. | Copy: `which gh` → none. `import-github 7 --area panels-ui` → title `Garbled non-ASCII text in translations: LoadStr templates composed with UTF-8 (Find status line, Find log, message boxes)` (118 chars), *Problem* `> **Version:** …`, *Expected* `(to be written)`, `check` → `TOTAL: 0`. | "1. `BL import-github <N> --area <area>`, where *area* is the area the maintainer named, else `panels-ui` (corrected in step 3); refusals as now. 2. Read `issue.md`. 3. Rewrite the body …; `BL set <slug> type=<t> severity=<n> area=<a> 'title=<English, ≤ 80 chars>' --log 'fields set from the issue text'`. 4. `grep -n '(to be written)' backlog/items/<slug>/desc.md` → no output." |
| S10 | I:221-227, I:302-303; SR:76-82 | **Step 6 lacks exact commands.** There is no command for the build (run from Bash or PowerShell?), none for `saltests` (`build/tandemcommander/Debug_x64/saltests/saltests.exe` exists), and none for the two-stage `.slt` refresh (`translate.merge --templates <dir>`, no path given). The encoding check prints `TOTAL: 0 finding(s)`, not `TOTAL: 0`. | `python tools/check_encoding.py --strict` → last line `TOTAL: 0 finding(s)`. `find build -iname 'saltests*.exe'` → the path above. | Step 6, written as commands: "PowerShell tool: `.\build.cmd` (or `.\build.cmd full`) → last line `BUILD SUCCEEDED`; `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → exit 0; Bash: `python tools/check_encoding.py --strict` → last line `TOTAL: 0 finding(s)`, exit 0." For the `.slt` refresh, give the exact two commands with `--templates build/translator/templates`, or say: "UI strings added or removed → stop (§3 reason 2); the run never does the refresh." |
| S11 | SR:83-88; I:39-41 | **The probe command breaks in Bash.** I §0.6 names the Bash tool for git and `BL` and no tool for probes. The probe command in SR §2.7 uses backslash paths. In Bash, `tools\run_on_hidden_desktop.ps1` becomes `toolsrun_on_hidden_desktop.ps1`. The `-Log <out.txt>` location is not fixed either. | `echo powershell -File tools\run_on_hidden_desktop.ps1 …` in Bash → `powershell -File toolsrun_on_hidden_desktop.ps1 …`. | SR §2.7: "Run it with the **PowerShell tool** (never Bash): `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\<NNN>-<short>\probe\result_<label>.txt -CommandLine "…"`." Add the PowerShell tool to I §0.6: "the **PowerShell** tool for `build.cmd`, `saltests.exe` and probes". |
| S12 | I:195 vs SR:10-26 | **Two different rules for clarify.** Step 5 says "Otherwise take your **Recommended** option" and writes `(autonomous run: recommended option)`. SR §1 says that an answer from the item or a standing rule (step 2) comes **before** the recommended option (step 3), and writes `(autonomous run: <item \| rule \| recommended \| conservative>)`. | Reading. | Step 5, clarify row: "For each question apply SR §1 steps 1–4 **in order** (maintainer-owned → stop; the item or a rule answers → that; else the Recommended / Suggested option; else the conservative one). Write the bullet exactly as SR §1 says." |
| S13 | I:198; SR:130 | **No rule when a HIGH finding survives the second `speckit-analyze` run.** Only "CRITICAL left → stop" is defined. The contract (`skills.md` 7) says "CRITICAL / HIGH fixed". | Reading. | "HIGH left after the second run → record each in `fix-log.md` with why it is accepted, and continue only if it touches no FR of the item; otherwise stop (step 10, SR §3 #9)." Or: treat HIGH like CRITICAL. |
| S14 | I:262-265 (8.2), I:349-356 (10.3), I:209-213 | **Items created in 8.2 and 10.3 get no writing rules.** Only step 5 points to `/tandem-backlog` §2.1 steps 3–7. The `BL new` calls of 8.2 (leftovers, person steps) and 10.3 (decision / person-step / split) have no rule to complete the body and verify it with `grep '(to be written)'`. None of the references include B §0.2's rule "no backslash on the command line" (`\\?\` and UNC paths are common in this project's items). | Reading. Bash collapses `'\\server\share'` to `\server\share` (`printf` measured). | Add to I §0: "**Every `BL new` of a run** follows `/tandem-backlog` §0.2 (quoting, no backslash on the command line) and §2.1 steps 2–7 (look for an existing item, fields, title, create, complete the body, `grep '(to be written)'` → nothing)." |
| S15 | I:49-50 vs I:90, 125, 185, 310, 333, 362 | **Commit templates leave out the attribution lines.** §0.7 requires them on every commit, but each template is a single `git commit -m "…"` without them. An agent that copies a template exactly omits them. | Reading. | §0.7: "Every commit of the run is `git commit -m "<subject>" -m "<body, optional>" -m "<attribution lines>"`; the templates below give the subject only." |
| S16 | I:93-95, I:372-385 | **The dry run has no fixed report format.** §11 lists no outcome for a dry run, and step 2 gives only a list of contents. It is also not said whether the preconditions of step 1 apply to a dry run. | Reading. | Step 2: "A dry run runs step 1 (read-only) and ends with: `Outcome: dry-run` · `Item: <SLUG> - <TITLE> (Next #<p>)` or `Item: - (nothing eligible)` · `Skipped: <slug: reason; …>` · `Would check: <step 3 plan, one line>` · `Lock: <lock status output>`." Add `dry-run` to §11's outcome list. |
| S17 | I:260-265 (8.1); B:383-395 (§2.13) | **Closing a `github#N` item silently drops the reply draft.** `remove` deletes `issue.md` and `reply.md`, and nothing tells the maintainer that issue #N needs an answer. The skills say "never post", so the person step is lost. | Reading. `remove` deletes the whole folder (`backlog.py` `cmd_remove`). | 8.1: "If the item's source is `github#N`: before `remove`, copy `issue.md` and `reply.md` to `specs/<NNN>-*/`, write the draft reply there, and add to `PERSON`: `answer and close GitHub issue #N (draft in specs/<NNN>-*/reply.md)`." Add the same rule to §2.13 step 2 (person step in the report). |
| S18 | SR:32 vs I:277-280 | **CHANGELOG: two rules that contradict.** SR §1 makes "release notes, a policy stated in `CHANGELOG.md`" maintainer-owned (meaning stop), while step 8.4 makes the run write `CHANGELOG.md` entries. An agent cannot tell whether its entry is "release notes". | Reading. | SR §1, *Public claims*: "… the GitHub release text, a **policy** stated in `CHANGELOG.md` (an entry describing this feature's fix under `— unreleased` is the run's job, step 8.4)." Step 8.4: "If there is no `— unreleased` section, do not create one (the version number is maintainer-owned): put the entry text in `closing-report.md` and add it to `PERSON`." |
| S19 | I:322-326; SR:127 | **The merge recipe after a failed fast-forward is incomplete.** Measured, the manual merge conflicts in **three** files: `BACKLOG.md` (content), `RUNS.md` (content), and `desc.md` (modify/delete). The recipe covers only the item folder and `RUNS.md`. SR §3 #6 words the reason differently from step 9. | Copy: branch `300-ff-test` (start, a leftover item, `remove --feature`, `closed` row), then a foreign commit on `main`, `merge --ff-only` → exit 128, step 10 `block` + `blocked` row, `git merge 300-ff-test` → `CONFLICT … BACKLOG.md`, `CONFLICT … RUNS.md`, `CONFLICT (modify/delete) … desc.md`. | Reason (step 9 and SR #6, identical): "`fast-forward failed - finished work on <BRANCH>; merge by hand: git merge <BRANCH>; on conflicts: git rm backlog/items/<SLUG>/desc.md, keep both RUNS.md rows, take the branch's backlog/BACKLOG.md, then python tools/backlog/backlog.py sync and check`". |
| S20 | I:338-348 (10.2a) | **10.2a does not fix the order of copying and moving.** Whether all folders are copied first or each is copied and moved in turn is not said. If all are copied first, each `move` exits 1 with an `orphan` finding for the items not yet moved. If one copied item is `related` to another not yet copied, it exits 1 with `ref`. The skill says exit 1 is never ignored. | Copy: `git checkout <BRANCH> -- backlog/items/finding-a…` and `…/finding-b…`, then `move finding-a-on-the-way --section inbox` → exit 1 `orphan: … finding-b…`; the second move → exit 0, `check` → 0. | "First copy **every** listed folder (`git checkout <BRANCH> -- backlog/items/<s>` for each), then run `BL move <s> --section inbox` for each. `orphan` findings that name a listed slug are expected until its own move; after the last move, `BL check` must be `TOTAL: 0`." |

### NOTE

| # | Where | Observation | Suggested action |
|---|---|---|---|
| N1 | B:356-402 | The operations are numbered 2.10, 2.12, 2.13, **2.11** (*check* comes last). | Renumber: 2.11 *unblock*, 2.12 *close*, 2.13 *check*, and fix the cross-references (§2.8, §2.10, R §5). |
| N2 | B:191-194 vs B:57-60 | The `BL new` template continues lines with `\`, but §0.2 says "never put a backslash on the command line". | "…never put `\\` or a path backslash on the command line (a `\` that ends a line is fine)". |
| N3 | I:221, I:303; SR:77 | `check_encoding.py --strict` prints `TOTAL: 0 finding(s)`. | Write the literal output (see S10). |
| N4 | R:278 | The `orphan` fix, "`BL move <slug> --section <its section>`", is refused for a `parked` or `rejected` orphan unless `--reason` is given (measured: `refused: moving to 'Parked' needs --reason`); an `in-progress` orphan cannot be moved at all. | "…for `parked` / `rejected` add `--reason '<the reason from its header>'`; an `in-progress` orphan → report it (only the run handles it)." |
| N5 | `backlog.py` `place_row`, `cli.md` `move` | `--position 0`, a negative position, and a position above *n* are all accepted without a word (they mean top or end). | State this in `cli.md`, or refuse `< 1`. |
| N6 | R:146 | R says "`person-step` (always `who: person`)", but the tool accepts `--type person-step --who agent` (measured, exit 0). | Let the tool refuse it, or soften R. |
| N7 | B:307 | The *move* report needs the old and new positions, but the tool prints only `slug: Old -> New`. | "Read the positions with `BL list --json` before and after." |
| N8 | B:247 | The column *Item (slug)* could hold the title, the slug, or both. | "`<title> (<slug>)`". |
| N9 | SR:111-112 | "While `microsoft/winget-pkgs#426090` is open" cannot be checked: the run may not talk to the network. | "As long as the backlog holds an item whose slug contains `426090`, treat the PR as open." |
| N10 | B:284, B:350, B:359-360, B:105-106 | There are four different `--reason` formats for *parked* / *rejected*. | Use one: `'<why>; maintainer YYYY-MM-DD'`. |
| N11 | B:390-395 | The report "dependents updated: <slugs or none>" cannot be filled from the tool's output. | Step 0: `grep -l -e 'depends-on: .*<slug>' -e 'related: .*<slug>' backlog/items/*/desc.md`. |
| N12 | SR:87 | `-Exe build\tandemcommander\Debug_x64\tandemcommander.exe` holds only when `OPENSAL_BUILD_DIR` is not set. | "`<OPENSAL_BUILD_DIR or build>\tandemcommander\Debug_x64\…`". |
| N13 | I:109 | When an item is run again after `unblock`, the earlier stopped branch (named in the reason and the *Log*) is ignored, and its work in progress with it. | "If the *Log* names an earlier branch, read its `fix-log.md` in step 3 (`git show <branch>:specs/…/fix-log.md`)." |
| N14 | I:90 | The *nothing-to-do* path commits without running `BL check` first; every other path runs it. | Add `BL check` before `git add`. |
| N15 | I:275-276 | "The row of its area in *Index by area*": the index uses its own areas, not the backlog's. | "…the row whose title fits the feature; if none fits, leave the index unchanged." |
| N16 | `contracts/skills.md:28` vs B:79-82 | The contract lists `log` among the agent-mode operations; §0.3 does not. | Add it to one of them so the two lists agree. |
| N17 | R:277 | For an `overview` finding caused by a note row written by hand, the fix does not say to turn the note into an item and then delete the row. | Add one sentence. |
| N18 | I:328-370; B:68-71 | If the maintainer merges a *stopped* branch by hand to keep its work, an `in-progress` item reaches `main`. The management skill cannot close it (`remove --reason` refuses `in-progress`, and `remove --feature` is reserved for the run). | R §6: "an `in-progress` item on `main` after a manual merge → `BL remove <slug> --feature <NNN>` by the maintainer". |

---

## Walk-through of the operations (copy, exactly as written)

| Operation | Commands run | Result |
|---|---|---|
| `add` (§2.1 steps 2, 5, 7) | the `grep -ril …` from step 2; the `BL new` template with `\` continuations; `grep -n '(to be written)'`; `BL check` | slug printed, *Inbox* row, `TOTAL: 0`; a `decision` gets three placeholders, which step 7's grep finds |
| `import-github` | `BL import-github 5 …` (already imported); `BL import-github 7 --area panels-ui`; `BL set … type= severity= area=`; `BL set … 'title=…'` | refusal names the existing slug; import works (S9); set works |
| `list` / `show` | `BL list --section next\|inbox\|parked\|rejected [--json]` | backlog order, positions; the *Inbox* is sorted by `created`, then slug |
| `triage` | `BL set who=person`, `BL set type=person-step`, `BL move --section person\|decisions\|next --position p` | works, but leaves placeholders (S7); `person-step` into *Next* is refused as R §6 says |
| `move` / `park` / `reopen` | `BL move … --section parked --reason …`; out of *Parked* without and with `--reason` | refusal `needs --reason (the new reason)`, then `open` with the reason cleared |
| `decide` | `BL log …`; `BL set type=bug --log …` (row moved to the end of *Next*); `BL move --section next --position 2`; rejecting with a dependent | works; rejecting with a dependent fails (M2) |
| `unblock` / `block` | `BL block … --reason …`, `BL unblock` | works (but `block` has no operation, S6) |
| `close` | `BL verify … --note …`; `BL remove … --reason …` with a dependent | dependents get `depends-on: []` and a log line |
| `check` | `BL check` | `TOTAL: 0` |

## Walk-through of `/tandem-backlog-implement` (copy with `.specify/`)

| Path | Result |
|---|---|
| Step 1 | `lock status` → `free`; `rev-parse` → `main`; `status --porcelain` → empty; `check` → `TOTAL: 0` |
| Step 2 | `next --json` → `{"slug": "temp-dir-walks-follow-junctions", "skipped": []}`; `--slug <person item>` → exit 1 `{"slug": null, "refused": …, "reason": "who person"}`; unknown slug → exit 1 JSON |
| Lock | `lock acquire --slug S` → path under `.git`; a second `acquire` → exit 1 `another run in progress: held since … by item S, branch -, host …`; `lock update --slug S --branch B` then `status` names the branch |
| Not reproduced | `verify`, `block`, `run-log --outcome not-reproduced`, `check`, `git add backlog`, commit, `lock release --slug` → tree clean, `next` skips S as `status blocked` |
| Nothing to do | bare `lock acquire`, `run-log --outcome nothing-to-do`, commit, bare `lock release` → works; `release --slug x` on a lock without a slug → refused |
| Start | `create-new-feature.sh --json --short-name …` → `{"BRANCH_NAME":"242-decide-something","FEATURE_NUM":"242"}`, branch created; the uncommitted `verify` change is carried to the branch; `start --feature 242`, `lock update` |
| Stop (10.1–10.7) | branch items listed by `git diff --name-only --diff-filter=A main...<B> -- "backlog/items/*/desc.md"` (two listed), copied and moved (S20); `new --type decision --related S`; `block` (item `open` on `main`, as step 10.2 says); `run-log --outcome blocked …`; commit; release → clean `main` |
| Numbering after a stop | `--dry-run` → `243-…` while `specs/` holds only `241-prev`, which confirms that the explicit folder of the first review's M1 is needed (S1) |
| Fast-forward failure | `merge --ff-only` → exit 128; `main` gets `block` and a `blocked` row; the manual merge conflicts in three files (S19) |
| Hooks | `auto-commit.sh after_plan` → `[Spec Kit] Add implementation plan`; `before_plan` → no-op (disabled in `git-config.yml`) |

## Verified as correct

- Every `BL` command and option named in the four skill files exists with
  exactly that syntax and behaves as the skills say: `check`, `sync`,
  `list --section/--area/--type/--status/--who/--min-severity/--json`, every
  section alias (`next`, `decisions`, `person`, `inbox`, `parked`,
  `rejected`, `progress`), `next --json/--slug`, `new` with all options,
  `import-github --area`, `set k=v --log`, `set 'title=…'`, `log`,
  `verify --note`, `move --section/--position/--reason`, `block --reason`,
  `unblock --note`, `start --feature`, `remove --feature` / `--reason`,
  `run-log` with all options, `lock acquire/update/release/status`.
- The first review's resolutions hold. Re-measured on this version:
  - M2: a hand-written row is kept, and `sync` refuses (exit 1, naming the line).
  - S2: a reason containing a line break is refused.
  - S9: leaving *Rejected* for *Inbox* needs `--reason`.
  - S12: `lock update` works.
  - S14: `remove --reason` works and logs the dependents.
  - N5: an unknown `--slug` gives JSON.
  - N16: the lock state is read first in step 1.
  - M1: the folder is now passed explicitly. Its mechanism is right; only
    how the value is obtained is open (S1, and M1 above).
- Referenced files and symbols exist:
  - `specs/098-long-path-overruns/probe/fix_probe_lib.ps1` defines
    `Backup-Reg` (line 154) and `Restore-Reg` (line 161, with an export and
    hash comparison as the check).
  - `pack241_probe.ps1` dot-sources the library and uses
    `%TEMP%\tc241_backup.reg`, which matches SR §2.8.
  - `tools/run_on_hidden_desktop.ps1` takes `-Log` and `-CommandLine`
    (both mandatory) and `-WaitSeconds`.
  - `.specify/extensions/git/scripts/bash/create-new-feature.sh` has
    `--json`, `--short-name`, `--dry-run`, `GIT_BRANCH_NAME`, and
    `git fetch --all --prune`. The PowerShell variant has the same.
  - `speckit-specify` uses an explicit `SPECIFY_FEATURE_DIRECTORY` "as-is"
    and writes `.specify/feature.json`.
  - `git-config.yml` enables auto-commit after specify, clarify, plan,
    tasks and implement.
  - The spec template has the `**Input**` line.
  - `specs/069-finish-encoding-fixes/contracts/fix-protocol.md`, the
    *Index by area* of `FEATURE-HISTORY.md`, `## [0.1.11] — unreleased` in
    `CHANGELOG.md`, the constitution's *Release Documentation*,
    `check_encoding.py --strict`, and the `general-purpose` agent type all
    exist.
  - The skill-internal references resolve: `/tandem-backlog` §2.1 steps
    3–7, SR §1–§3, R §1–§6, I steps 10.2a and §11.
- On every path of the run, the lock is released, the run ends on `main`,
  nothing is pushed, and the journal row reaches `main` (paths
  not-reproduced, nothing-to-do, stop, and via fast-forward).
- The agent-mode rules of the management skill match FR-014 and
  `contracts/skills.md`, apart from S8 and N16. The modes, the item
  resolution by title, and the rule "one changing command at a time" are
  stated without gaps.

---

## Resolution (2026-10-17)

Both skills were rewritten with the suggested wordings (taken over almost
word for word where the report gave them); tool additions:
`list --needs / --related-to`, `--position` below 1 refused, a
`person-step` must have `who: person` (`value`). Tests: 58, all green.

| # | Resolution |
|---|---|
| M1 | I §0.7 "never put item text on a command line"; step 4.2 writes the specify input into a scratchpad file; the hook rule passes only `'Backlog item <SLUG>'` (single quotes) with `GIT_BRANCH_NAME`. Measured in a temporary repository: `--dry-run` computes `243-next-item` next to an unmerged `242-…` and creates nothing; `GIT_BRANCH_NAME='243-next-item'` creates exactly that branch. |
| M2 | B §2.9: dependents listed first (`BL list --needs`); an answered decision is closed with `BL remove --reason` (dependents may start), not rejected; B §2.11 *reject*: dependents resolved first (reject them too, or drop the dependency). |
| S1 | Step 4.1 computes `BRANCH` with `create-new-feature.sh --dry-run` before specify; the input carries `GIT_BRANCH_NAME` and `SPECIFY_FEATURE_DIRECTORY`. |
| S2 | Step 4 numbered 4.1–4.5: checks and the rename before `start` and `lock update`. |
| S3 | Step 10.7: a stop after specify ran without a branch removes what specify left on `main` (`git status --porcelain` must be empty). |
| S4 | B §0.2 and I §0.8: exit 1 has two forms (`refused:` vs `check after the change found problems:` — never repeat the latter); B §0.5: `BL check` before every changing operation. |
| S5 | Every operation has a fixed *Report:* line; §3 defines the report as exactly those lines + the check line + the agent-mode line. |
| S6 | New operation `block` (§1 row, §2.13). |
| S7 | B §2.5 step 4.2 and §2.7: after `set type=…` the added sections are written and `grep '(to be written)'` must be empty; a decision converted to work keeps its *Question / Options / Recommendation* as the record (§2.9). |
| S8 | B §2.8 table has an agent-mode column (log line instead of an Evidence edit); §0.5 agent mode fixes only its own items. |
| S9 | B §2.2: area default `panels-ui` corrected later, title shortened with `set 'title=…'`, *Expected* must not stay a placeholder. |
| S10 | I step 6 is a table of exact commands and outputs (`TOTAL: 0 finding(s)`, `BUILD SUCCEEDED`, `saltests: <n> checks, 0 failed` — measured: 22,737 checks); the `.slt` refresh is never done by a run (stop). |
| S11 | I §0.6 adds the PowerShell tool for build, saltests and probes; SR §2.7 names it, the `-Log` location and `<build>` (`OPENSAL_BUILD_DIR`). |
| S12 | I step 5 clarify row applies SR §1 steps 1–4 in order and writes the bullet as SR §1 says. |
| S13 | I step 5 analyze row: HIGH left after the second run → stop if it concerns a requirement of the item, else recorded as accepted. |
| S14 | I §0.9: every `BL new` of a run follows the management skill §0.2 and §2.1 steps 2–7. |
| S15 | I §0.10: every commit is `git commit -m '<subject>' -m '<body>' -m '<attribution lines>'`. |
| S16 | Dry run: preconditions apply, fixed five-line message, outcome `dry-run` in §11. |
| S17 | I step 8.1 keeps `issue.md` / `reply.md` in the feature folder with a draft answer and adds the answer to `PERSON`; B §2.15 step 2 tells the maintainer. |
| S18 | SR §1 *Public claims*: the run's own `— unreleased` entry is not a policy; I step 8.5: no `— unreleased` section → the entry goes to the closing report and `PERSON`. |
| S19 | One reason text (step 9, referenced word for word by SR §3 #6) with the full merge recipe (desc.md removal, both `RUNS.md` rows, the branch's `BACKLOG.md`, `sync`, `check`). |
| S20 | I step 10.2a: copy every folder first, then move each; expected interim `orphan` findings named. |
| N1 | Operations renumbered 2.1–2.16 in table order; references updated (reference.md → §2.15). |
| N2 | B §0.2: a `\` that continues a command line is fine. |
| N3 | Encoding guard output written literally. |
| N4 | R §6 `orphan`: `--reason` for parked / rejected; in-progress → the new row. |
| N5 | `--position` below 1 refused; past the end = end (`cli.md`). |
| N6 | Tool: `person-step` requires `who: person` (test). |
| N7 | B §2.6 reads the positions with `BL list --json` before and after. |
| N8 | *Item* column = `<title> (<slug>)`. |
| N9 | SR §2.12: the PR counts as open while an item slug contains `426090`. |
| N10 | B §0.6: one reason form `'<why>; maintainer YYYY-MM-DD'`. |
| N11 | Dependents / relations from `BL list --needs` / `--related-to` (new filters, test). |
| N12 | SR §2.7 `<build>` = `OPENSAL_BUILD_DIR` or `build`. |
| N13 | I step 3 reads the record of an earlier stopped branch named in the item's log. |
| N14 | Nothing-to-do path runs `BL check` before the commit. |
| N15 | I step 8.4: the index row whose title fits, else unchanged. |
| N16 | Agent-mode list includes `log` in both the skill and the contract. |
| N17 | R §6 row for a hand-written note row. |
| N18 | R §6 row for an `in-progress` item on `main` after a manual merge. |
