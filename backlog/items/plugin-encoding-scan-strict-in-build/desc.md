---
title: The build runs the plug-in encoding scan strictly for the shipped plug-ins
type: tech-debt
status: open
severity: 2
area: tooling
source: leftover:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [check-encoding-skips-header-files]
depends-on: [dbviewer-field-length-separator, renamer-wtf8-names-shown-as-mojibake, uniso-hfs-names-lossy-surrogates, uniso-joliet-file-names-wtf8-garbled, ftp-wtf8-name-listing-round-trip]
reason: -
---

# The build runs the plug-in encoding scan strictly for the shipped plug-ins

## Problem

`tools/check_encoding.py --plugins` is a report only (feature 239): it never fails and the build
does not run it, so a new encoding defect in a plug-in passes unnoticed. Feature 255 (stopped
after its second review; the work is on branch `255-plugin-encoding-findings`, not on `main`) gave
the 78 findings verdicts: 68 annotated as harmless on the branch, 10 real defects with their own
items - and review 2 showed one more annotated site is real (FTP,
`ftp-wtf8-name-listing-round-trip`). Once the branch is finished and the items of the **shipped**
plug-ins are closed, the scan of the shipped plug-ins reports 0 and can guard the build like the
core's scan does.

## Evidence

`specs/255-plugin-encoding-findings/verdicts.md` (branch `255-plugin-encoding-findings`) (the 78 rows) and `fix-log.md`; at the end of
feature 255 the scan reports 10 findings: 5 in shipped plug-ins (DB Viewer 1, Renamer 1, UnISO 3 -
the items this one depends on) and 5 in plug-ins that are off (Automation 1, CheckVer 1,
Multimedia Viewer 1, UnMIME 2). `build.cmd` runs only `check_encoding.py --strict` (the core).
The scan reads `*.cpp` only - headers are item `check-encoding-skips-header-files`.

## Expected

`build.cmd` fails when a shipped plug-in (`plugins.cfg` on) has an unannotated finding, and passes
at the tree's state; plug-ins that are off are still reported, not failed.

## Approach

An option such as `--plugins --strict` that fails only on files of plug-ins that are on in
`plugins.cfg`, run by `build.cmd` next to the core's scan. A file under `shared/` counts only when
a shipped plug-in's project builds it (`shared/lukas/utildlg.cpp`, for one, is built by none).
Measure with a negative control (one added sink line fails the build).

## Notes

Changes feature 239's "report only" requirement and the build gate - triage is the maintainer's.
Items for the plug-ins that are off (`automation-script-folder-list-code-page`,
`checkver-log-script-path-garbled`, `mmviewer-open-error-name-mojibake`,
`unmime-progress-title-name-mojibake`) do not block it.

## Log

- 2026-10-20 — created (source leftover:255)
- 2026-10-20 — set depends-on=dbviewer-field-length-separator,renamer-wtf8-names-shown-as-mojibake,uniso-hfs-names-lossy-surrogates,uniso-joliet-file-names-wtf8-garbled
- 2026-10-20 — set related=check-encoding-skips-header-files
- 2026-10-20 — set depends-on=dbviewer-field-length-separator,renamer-wtf8-names-shown-as-mojibake,uniso-hfs-names-lossy-surrogates,uniso-joliet-file-names-wtf8-garbled,ftp-wtf8-name-listing-round-trip
- 2026-10-20 — moved to Inbox
- 2026-10-20 — moved to Next position 77
