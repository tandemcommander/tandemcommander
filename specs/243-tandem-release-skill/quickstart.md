# Quickstart / validation: `tandem-release` (feature 243)

All commands from the repository root. Nothing here prepares a real release:
the real `0.1.10` preparation is the maintainer's own run.

## Prerequisites

- Python ≥ 3.13 on PATH (`python --version`), git.
- A clean work tree on branch `243-tandem-release-skill`.

## V1 — Unit tests of the tool

```bash
python -m unittest tools/release/test_release.py -v
```

Expected: all tests pass; they cover the states (data-model *State*), each
refusal, the fold with 0/1/2 unreleased sections, idempotence, BOM/CRLF
preservation, the winget summary replica, every `check` rule by a seeded
defect.

## V2 — `status` on the real tree (read-only)

```bash
python tools/release/release.py status 0.1.10
python tools/release/release.py status 0.1.9     # refused: tag-exists
python tools/release/release.py status 0.2.0     # refused: line-change
python tools/release/release.py status 0.1.010   # refused: version-form
```

Expected for 0.1.10 (on 2026-10-17, branch `243-…`): previous 0.1.9 / build
193, build 194, state `prepared-earlier`, features 124–241, warnings
`branch-not-main` and `release-branch-ahead`; gating lists the four person
steps of *Current release*. `git status` unchanged after each call.

## V3 — `stamp --dry-run` and `check` on the real tree

```bash
python tools/release/release.py stamp 0.1.10 --dry-run
python tools/release/release.py check 0.1.10
python tools/release/release.py summary 0.1.10
git status --porcelain     # empty
```

Expected: the dry run lists the date moves 2026-10-14 → today in
`CHANGELOG.md`, `PRIVACY.md`, `CLAUDE.md`, the project reference, the release
notes, and the fold of `[0.1.11] — unreleased`; `check` reports findings
(dates, `changelog-unreleased`, `changelog-lead`); `summary` shows the lead
lacks `**Build 194.**`.

## V4 — Full skill run on a throw-away worktree

```bash
git worktree add <scratch>/tc-release-0110 main
cd <scratch>/tc-release-0110
# in a Claude session started there: /tandem-release 0.1.10
```

Expected: the skill asks about the gating person steps (and the open
decision `post-142-fixes-joining-0-1-10-decision`); after "yes" it stamps,
writes the texts, `check` 0 findings, `check_encoding` TOTAL 0, one commit
`Version 0.1.10: the tree prepared for the release (<today>)`; no tag, no
push. A second `/tandem-release 0.1.10` the same day: `unchanged`, no
commit. Then:

```bash
cd -; git worktree remove --force <scratch>/tc-release-0110
git branch -D <worktree branch if one was created>
```

(The worktree is on a detached copy; nothing reaches `main`.)

## V5 — Refusal on a dirty tree and not on `main`

In the worktree of V4 before the run: touch a tracked file → `status`
reports `dirty-tree`; check out a branch other than `main` → the skill asks
and a "no" ends the run with `git status` unchanged.

## V6 — Records of the procedure

```bash
grep -n "temp/release_notes\|SHA-256\|VirusTotal" backlog/RELEASE.md     # no hit
grep -n "Release records" backlog/RELEASE.md CLAUDE.md .specify/memory/constitution.md
grep -n "Version\*\*: 3.2.0" .specify/memory/constitution.md
python tools/backlog/backlog.py check
```

Expected: one list of release records in `RELEASE.md`, pointed to by the
other two; constitution 3.2.0; backlog check 0 findings with the two new
*Inbox* items.
