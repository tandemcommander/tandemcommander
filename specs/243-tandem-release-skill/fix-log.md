# Fix log — 243 tandem-release skill

**Branch**: `243-tandem-release-skill` (from `main` at `c3319ffa`, 2026-10-17)
**Spec / plan / tasks**: `spec.md`, `plan.md`, `tasks.md` in this folder.
**Analysis**: `temp/tandem-release/PODKLADY.md` (not tracked; condensed in `research.md`).

## Decisions

- 2026-10-17 — clarify session: HEAD of the current branch, question when not
  on `main`; verification = consistency check + encoding guard only; open
  gating person steps → one question; changelog lead `**Build N.**` required,
  no regrouping, constitution amended; release-procedure records fixed here,
  SHA-256/VirusTotal step removed, copyrights and the winget README claim to
  *Inbox*, `shellext.rc` out of scope (not shipped).
- 2026-10-17 — the maintainer asked to run tasks and implement without
  stopping after the plan.

## Measurements

- 2026-10-17 — Python 3.14.6; `spl_vers.h` UTF-8 with BOM, the Markdown
  records and the `.iss` without; all LF in git, CRLF in the work tree
  (`core.autocrlf=true`).
- 2026-10-17 — `tools/backlog/backlog.py lock status` prints `free`, exit 0.
- 2026-10-17 — winget constants: `$SummaryMaxChars = 900`,
  `$SummaryWrapColumn = 76` (`publish.ps1:83-84`).

## Progress

- 2026-10-17 — `tools/release/release.py` (status, stamp, check, summary) and
  `test_release.py` with a miniature repository (`fixtures/repo`): 38 tests;
  the first run had 37 green and one wrong test (the `#`-line case did not
  put `#7` at a line start - the test, not the tool, was fixed).
- 2026-10-17 — the winget replica reproduces the recorded 0.1.9 manifest
  (`tools/winget/manifests/0.1.9/…locale.en-US.yaml`) line by line (T024).
  Negative control: wrap column 75 instead of 76 → the test fails.
- 2026-10-17 — real tree, `status 0.1.10`: previous 0.1.9 / 193, build 194,
  state `prepared-earlier`, features 124–241 (105), issues #3 #5 #6 #7 #8;
  planned: the fold of `[0.1.11] — unreleased` into `[0.1.10]` and the date
  moves 2026-10-14 → 2026-10-17 in the changelog, PRIVACY, CLAUDE.md, the
  project reference and the release notes. `check 0.1.10` lists exactly
  these plus the missing `**Build 194.**` lead (finding F8 confirmed).
- 2026-10-17 — deviation from research R4: the fold refuses whenever more
  than one section is folded and any has `###` groups (stricter; recorded in
  R4). Deviation from contracts: *Current release* cannot name the hash of
  the commit that writes it; it names the commit subject instead
  (`release-current` checks heading and the gating list).
- 2026-10-17 — `RELEASE.md` *Current release* of 0.1.10: the numbered list
  became the `Gating person steps:` list; first written with a parenthesis
  before the colon, which the tool did not recognize (`release-current`
  finding) - the line now starts with `Gating person steps:`.
- 2026-10-17 — *Inbox*: `unshipped-resources-still-carry-2023-open-salamander-only`,
  `winget-readme-names-a-publish-ps1-check-that-does-not-exist`;
  `backlog.py check` TOTAL 0. `check_encoding.py --strict` TOTAL 0.
- 2026-10-17 — V2/V3 on the real tree (clean, branch 243): `status 0.1.9`
  → `tag-exists`; `0.2.0` → `line-change`; `0.1.010` → `version-form`;
  `stamp 0.1.10 --dry-run` → 5 files (changelog fold, dates); `summary
  0.1.10` → 172 characters, `changelog-lead` (no `**Build 194.**`);
  `git status` unchanged. Found: a released or other-line version also
  printed a misleading `inconsistent:` line → `evaluate` stops after
  `tag-exists` (state `released`) and after `not-higher` / `line-change`
  (state `refused`); test added (commit 8e6f398d).
- 2026-10-17 — V4/V5 on a throw-away detached worktree of 8e6f398d (scratch
  directory, removed afterwards): a touched file → `dirty-tree`, nothing
  written; `stamp 0.1.10` → 5 files, minimal diff, CRLF kept, 11 changelog
  headings (one per tag + 0.1.10); `check` → only `changelog-lead`; the lead
  written as the skill would (`**Build 194.** Bug-fix release. …`) →
  `check` 0 findings, `summary` 200 characters, `check_encoding` TOTAL 0;
  commit; a second `stamp` → `unchanged`, state `prepared-today`; `stamp
  --date 2026-10-18 --dry-run` → exactly the six date moves in 5 files.
  The full skill (questions, release notes for 143–241) was not run: that
  is the maintainer's real preparation of 0.1.10.

## Review (refute-first, independent agent, 2026-10-17)

Nine findings, none high; all fixed (44 tests, 6 new):

1. *Medium* — a fold took any first paragraph as a lead: a prose entry
   (0.1.9's form) opening an unreleased section was dropped (only printed as
   `dropped-lead:`) or became the release lead. → A lead is only a paragraph
   starting with `**Build ` or the lead of the target's own dated section;
   any other first paragraph stays in the body (`is_release_lead`); tests
   `test_prose_entry_stays_in_body`, `test_prose_unreleased_gets_placeholder`.
2. *Medium* — `check` passed with stale text in *Status* and *Current
   release* after a re-run on another day. → `claude-status` /
   `release-current` reject "the tree prepared for the release (<other
   date>)"; `release-current` requires the feature range; SKILL step 6
   rewrites Status, Current release, the build-history summary and the
   notes on every run (the check cannot judge their content).
3. *Medium* — the product-line range was not compared with the changelog,
   counted every "feature N" in prose, and printed "244–244". → features =
   numbers cited in parentheses (`cited_features`; 105 = 105 on the real
   0.1.10 region, measured); `claude-product` / `reference-product` compare
   with them; a single feature prints as one number.
4. *Medium* — SKILL asked multi-select questions the question tool cannot
   ask (≤ 4 options; 13–17 candidates). → numbered list in the message,
   options *None* / *All* / *Stop* plus free text.
5. *Low/medium* — "another day = run again" was the last maintainer step
   (after tagging) in reference §6, and RELEASE.md numbered the closing pass
   after the skill. → both reordered.
6. *Low* — a detached HEAD was only a warning. → refusal `detached-head`.
7. *Low* — a newer tag only on the remote was not seen (build number could
   repeat). → one `ls-remote` of `v*` merged with the local tags; a previous
   tag only on the remote refuses (`no-previous-tag`, fetch first); warning
   `remote-tags-not-fetched`; test with a bare remote.
8. *Low* — "In <P-old>: nothing described here differed." stayed after the
   shift. → dropped; test `test_next_version_privacy_chain`.
9. *Low* — constitution said "each version's section" (unreleased ones
   too) → "each released version's section"; SKILL §0.4 vs its own decide
   call → short self-written sentences allowed; `/tandem-backlog decide`
   would ask more questions → the skill uses its "answered" path with
   `backlog.py log` + `remove`; the stop report says a re-run needs the
   edits committed or discarded; warning `date-past`; `REQUIRE_…` gets the
   interface number too.

Held up (reviewer): BOM/CRLF, the multiset of changelog lines across the
real 0.1.10 fold, idempotence, the date move 11-02 → 11-05, the 0.1.11
chain after a local `v0.1.10`, the winget replica against
`publish.ps1:119-207` (only difference: code points vs UTF-16 units), every
refusal writes nothing, the clarifications are reflected in the skill.
