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
