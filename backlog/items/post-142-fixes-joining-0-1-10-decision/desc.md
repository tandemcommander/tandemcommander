---
title: Which post-142 fixes join 0.1.10 (197 data loss, 217 exit hang, others)?
type: decision
status: open
severity: 7
area: build-release
source: leftover:197
who: person
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Which post-142 fixes join 0.1.10 (197 data loss, 217 exit hang, others)?

## Problem

The state prepared as 0.1.10 (`release-0.1.10-final`, features 124-142) still carries defects fixed later on other branches, among them a data loss and an exit hang that are in every release: feature 197 - F8 (no Recycle Bin) of a junction in a folder of 780+ characters, or of a folder holding one, deleted the junction TARGET's files ("in every release, also 0.1.9 and the prepared 0.1.10 - the maintainer decides whether 197 joins 0.1.10"); feature 217 - the intermittent "SSH handshake failed: Unable to exchange encryption keys" (about 1 in 256 connections) left a leak box that held the exit, so the program did not end within 30 s (seen in the 0.1.10 closing pass, 133's probe 74 / 2). Further fixes after 142 include data losses in narrow scenarios (144-146: archive edits and operations through a re-pointed drive letter; 199: the Renamer renaming to another file's 8.3 short name). Which of them ship in 0.1.10 is an open maintainer question; the migration had reduced it to "(e.g. 197)" in `RELEASE.md`.

## Evidence

NEXT-WORK at 7993914c: L786-788 ("the maintainer decides whether 197 joins 0.1.10"), L61-68 (0.1.10 closing pass, commit `4c852fe9`: 133 at 74 / 2 with the leak boxes at exit), L757-768 (the handshake failure seen again on 2026-10-13, "the program did not end within 30 s"). `specs/FEATURE-HISTORY.md` entries `197-deep-junction-delete`, `217-sftp-failed-handshake`, `144-`, `145-`, `146-`, `199-renamer-short-name`; `CHANGELOG.md` lists features 143-242 under the next version. Branches: `release-0.1.10-final` (to release) and `release-0.1.10` (on `origin`, must not be tagged - 132 without 135). Found by the review of the migration (`specs/242-backlog-system/ledger/review.md`, S6).

## Expected

The maintainer's choice is logged here and in `backlog/RELEASE.md` *Current release*; the release branch, `CHANGELOG.md` (which version lists which feature) and the 0.1.10 release notes agree with it.

## Notes

Cherry-picking changes the state the 0.1.10 closing pass verified; the release's probes (and those of the picked features) have to be run again on the result. Releasing from current `main` changes the release's content from 124-142 to 124-242: the changelog sections, `PRIVACY.md` and the person steps owed before the release grow with it.

## Question

Which fixes made after feature 142 join 0.1.10 - none, the data-loss fix 197 (with 217's exit hang), or everything up to now?

## Options

- **A - release `release-0.1.10-final` as it is.** 0.1.10 = 124-142 as prepared and verified; 197, 217 and the rest come with the next version. Users keep the junction data loss and the exit hang until then.
- **B - cherry-pick 197 (and 217) onto `release-0.1.10-final`.** Closes the data loss (and the hang) now; the changelog moves those entries into 0.1.10; the closing pass (build, `saltests`, `check_encoding.py`, the release's probes, `deepjunc_probe.ps1`, `sftp217_probe.ps1`) is run again on the result.
- **C - release from current `main` as 0.1.10.** Everything fixed so far ships; the release notes, `CHANGELOG.md`, `PRIVACY.md` validity and the owed person steps must be redone for 124-242.

## Recommendation

None recorded in the source. B is the smallest change that removes a data loss present in every release; the choice is the maintainer's.

## Log

- 2026-10-17 — created (source leftover:197)
- 2026-10-17 — moved to Decisions for the maintainer position 1
- 2026-10-17 — body written from NEXT-WORK L61-68, L757-768, L786-788 and FEATURE-HISTORY 197 / 217 (migration review S6)
