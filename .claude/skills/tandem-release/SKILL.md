---
name: "tandem-release"
description: "Prepare the Tandem Commander repository so that version <x.y.z> is released TODAY (feature 243): checks that the version is not released yet, bumps version and build, folds the unreleased changelog sections into the version's section, dates every release record, writes the changelog lead, the privacy sentence and the GitHub release notes (release_notes/), updates CLAUDE.md, the project reference and backlog/RELEASE.md, verifies (release.py check, encoding guard) and makes one local commit. Never builds, tests, signs, tags, pushes or publishes. Use only when the maintainer asks to prepare a release."
argument-hint: "<x.y.z> [--date YYYY-MM-DD] [--dry-run]"
compatibility: "Requires tools/release/release.py (feature 243), Python, git, backlog/ and tools/backlog/backlog.py (feature 242)"
user-invocable: true
disable-model-invocation: true
---

## User Input

```text
$ARGUMENTS
```

Arguments: the version `x.y.z` (**mandatory**), optional `--date YYYY-MM-DD`
(the planned release day; default today), optional `--dry-run`. Nothing
else. The maintainer may write in Czech — answer in Czech; everything
written into the repository is English.

---

## 0. Contract of a run

1. **The maintainer runs this skill and releases the result the same day.**
   The skill prepares the tree; the maintainer builds the signed program,
   tags, pushes and publishes (`reference.md` §6).
2. **Never**: build (`build.cmd`), run `saltests` or GUI probes, sign, build
   an installer, tag, push, publish a GitHub release, submit to winget,
   change a published version's records (older changelog sections,
   published release notes, other builds' history entries, recorded winget
   manifests), reorder `BACKLOG.md`, change backlog items other than the
   decision the maintainer confirms, force anything (`reset --hard`,
   `checkout -f`, `clean`, `--force`).
3. **Tools**: **Bash** from the repository root for git and Python.
   `RT` = `python tools/release/release.py`, `BL` = `python tools/backlog/backlog.py`.
   **Skill** for `/tandem-backlog`. Questions with the question tool
   (AskUserQuestion), **one at a time**, only those of §3.
4. **No repository text on a command line.** Texts with backticks, `$` or
   backslashes go into files with the editor; command lines carry only
   versions, dates, slugs, paths and short sentences you write yourself, in
   single quotes, without backticks, `$` or backslashes (step 8).
5. **Read [reference.md](reference.md)** §1 and §5 before step 5; §2–§4
   when a step points there.
6. **Every path ends** with the final report (§10). A stop before step 5
   leaves the tree unchanged; a stop after it leaves the edits uncommitted
   in the work tree and says so (never reset them) — and says that a new run
   is refused (`dirty-tree`) until the maintainer commits or discards them
   (`git diff`, then `git checkout -- <the listed records>` or a commit).

Values to remember once known: `VER`, `D`, `DL`, `P`, `PN`, `N`, `BRANCH`,
`STATE`, `FEATURES` (first–last, count), `ISSUES`, `GATING` (open slugs),
`DECISION` (slug or `-`), `WARN` (warnings).

---

## 1. Arguments

- No version, or more than one, or an unknown option → stop:
  `usage: /tandem-release <x.y.z> [--date YYYY-MM-DD] [--dry-run]`.
- `DATE_OPT` = `--date <D>` when given, else empty.

## 2. Status — change nothing

```text
RT status <VER> <DATE_OPT>
```

- Any `refused:` line → **stop**. Report each refusal with what to do:
  `tag-exists` → the version is released, pick the next; `dirty-tree` →
  commit or discard first (`git status`); `lock-held` → an autonomous
  backlog run is active; `copyright-year` → decide the copyright years
  first; `line-change` → a MAJOR/MINORA change needs a configuration
  migration decision; `inconsistent: …` → name the record and line;
  `detached-head` → check out the branch to release; `no-previous-tag` →
  when the tag is only on the remote, `git fetch --tags` first;
  `version-form`, `not-higher` → explain.
- Remember the values; `STATE` is `not-prepared` or `prepared-earlier` (go
  on) or `prepared-today` (go on: step 5 will print `unchanged`, the run
  ends at step 9 with no commit if nothing else is to be done).

## 3. Questions — before any change

Ask only what applies, in this order; a "no" or no answer → **stop**
(nothing changed).

1. **Not on `main`** (`warning: branch-not-main`): "The current branch is
   `<BRANCH>`, not `main`. Releases are prepared on `main`. Prepare
   <VER> on `<BRANCH>` anyway?"
2. **`minorb-skip`**: "<P> → <VER> skips a version. Go on?"
3. **`remote-unknown`**: "The remote tags could not be read; is `v<VER>`
   surely not published yet?" — **`remote-tags-not-fetched`**: "The remote
   has release tags this clone lacks (<tags>). Stop and fetch them first?"
   (*Stop* is the recommended option.) — **`date-past`**: "The release date
   <D> has passed. Prepare with that date anyway?"
4. **Open gating person steps** (`gating: open …` lines; with
   `prepared-earlier` from the last *Current release*): list each (slug,
   title, `backlog/items/<slug>/desc.md`) in the message, and the
   `gating-candidate:` lines separately as "possibly also relevant", then
   ask: "<n> person steps that gate the release are open. Prepare <VER>
   anyway?" (options: *Yes, prepare* / *No, stop*). With no listed gating
   steps but candidates, list the candidates numbered in the message and
   ask which of them gate this release — options *None of them* / *All of
   them* / *Stop*; the maintainer names a subset through the free-text
   answer ("Other": numbers or slugs). The answer becomes the
   `Gating person steps:` list of §6. (The question tool offers at most four
   options — never one option per candidate.)
5. **An open backlog decision about this release's content**:
   `grep -l -E '^type: decision' backlog/items/*/desc.md | xargs grep -l -F '<VER>'`
   → for each open one whose question is what ships in `<VER>` (today:
   `post-142-fixes-joining-0-1-10-decision`), state what this run means
   ("HEAD of `<BRANCH>` ships: features <FEATURES>") and ask whether to
   record it as the maintainer's decision. Yes → `DECISION` = slug (recorded
   in step 8). No → stop (the maintainer decides first).

`--dry-run` → run `RT stamp <VER> <DATE_OPT> --dry-run`, report its output
and the answers above, **end** (§10 dry-run form).

## 4. Content review (`reference.md` §2.4, §4) — change nothing

1. `git log --oneline v<P>..HEAD` and the features of `RT status`.
2. User-visible features without a changelog entry, changelog drafts left
   in fix-logs → list them numbered in the message; ask once — options
   *Add all* / *Add none* / free text naming the numbers to add. Agreed
   entries are written in step 6, before the verification.
3. Privacy triggers (`reference.md` §4): a trigger that applies while
   `PRIVACY.md`'s body does not describe it → ask the maintainer; "no" or
   unclear → **stop** (the statement must be updated in its own change).
   Note what you found for the privacy sentence (§2.3).

## 5. Stamp

```text
RT stamp <VER> <DATE_OPT>
```

- Exit 1 (`refused:`) → stop; the tree is unchanged.
- Note the `dropped-lead:` lines (to merge into the lead) and
  `changed: n file(s)` / `unchanged`.

## 6. Wording (`reference.md` §2, §3) — with the editor

Replace every placeholder and write the texts. **On every run — also
`prepared-earlier` with no placeholder left — re-read and rewrite items 2,
4, 5 and 6 so that they cover the whole content of the section** (features
<FEATURES>) and name today's date; a re-run on a later day folds new work
in, and these texts are what the check cannot judge.

1. `CHANGELOG.md`: the lead (§2.1); agreed missing entries from step 4
   (newest feature first, in the section's style).
2. `spl_vers.h`: the summary of the build-history entry (§2.2).
3. `PRIVACY.md`: the sentence for `<P>` (§2.3), re-wrapped.
4. `release_notes/release_notes_v<VER>.md` (§3).
5. `CLAUDE.md` *Status* (§2.5).
6. `backlog/RELEASE.md` *Current release* body (§2.6), with the gating list
   confirmed in step 3.

## 7. Verify

```text
RT check <VER> <DATE_OPT>
RT summary <VER> <DATE_OPT>
python tools/check_encoding.py --strict
```

- `check` must print `findings: 0`, `check_encoding` `TOTAL: 0`. Fix the
  wording and repeat (at most three rounds). Findings that remain → **stop
  without a commit**: report them; the edits stay in the work tree.
- `summary`: the length is reported in §10.

## 8. Backlog

- `DECISION` set (confirmed in step 3) → the "answered" path of
  `/tandem-backlog` §2.9, without its questions:
  1. `BL list --needs <DECISION>` → note the dependents;
  2. `BL log <DECISION> 'maintainer decision <D>: released as <VER> from <BRANCH>, features <FEATURES>'`;
  3. `BL remove <DECISION> --reason 'decided <D>: released as <VER> from <BRANCH>; maintainer'`.
  Report the dependents; the maintainer decides about them later.
- Defects found on the way that are not part of this release → *Inbox*
  through `/tandem-backlog add` (source `review:243`). Nothing else.

## 9. Commit

Only when step 7 passed and something changed:

1. Write the message to a file in the scratchpad (never on the command
   line):

   ```text
   Version <VER>: the tree prepared for the release (<D>)

   Build <N>, release dated <D>, features <FEATURES> since v<P>.
   <What changed: the changelog section (folded sections), the release
   notes, PRIVACY.md, CLAUDE.md, the project reference, RELEASE.md,
   spl_vers.h, the installer script.>

   Verified: release.py check 0 findings, check_encoding.py --strict
   TOTAL 0. Not done here - the maintainer's steps: build.cmd full release
   sign setup, the tag v<VER>, the GitHub release with
   tandemcommander-<VER>-x64-setup.exe attached, winget.

   <the attribution lines the session's instructions give for commits>
   ```

2. `git add` the changed records by path (the eight records, plus
   `backlog/` files changed in step 8), then `git commit -F '<file>'`.
3. `git status --porcelain` → empty.

## 10. Final report (in the maintainer's language)

```text
Prepared: Tandem Commander <VER> (build <N>), release date <D>, commit <hash> on <BRANCH>.
Content: features <FEATURES> since v<P>; GitHub <ISSUES>.
Changed: one line per record.
Verified: release.py check 0 findings; check_encoding TOTAL 0; winget summary <n> characters.
Gating person steps: <open ones, or none> (confirmed by the maintainer).
Decision recorded: <DECISION or none>.   Inbox: <added items or none>.
Warnings: <WARN or none>.
Maintainer's steps: reference.md §6, numbered, with <VER> and <D> filled in
(step 1: another day = run /tandem-release <VER> again first).
```

Dry run: `Dry run of <VER> (<D>): state <STATE>; would change: <list>;
questions answered: <…>; nothing written.` A stop: what stopped the run,
whether anything was written, what the maintainer can do.
