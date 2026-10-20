---
title: The build runs the plug-in encoding scan strictly for the shipped plug-ins
type: tech-debt
status: new
severity: 2
area: tooling
source: leftover:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: [dbviewer-field-length-separator, renamer-wtf8-names-shown-as-mojibake, uniso-hfs-names-lossy-surrogates]
reason: -
---

# The build runs the plug-in encoding scan strictly for the shipped plug-ins

## Problem

`tools/check_encoding.py --plugins` is a report only (feature 239): it never fails and the build
does not run it, so a new encoding defect in a plug-in passes unnoticed. Feature 255 gave all its
78 findings a verdict: 68 are annotated as harmless, 10 are real defects with their own items. Once
the items of the **shipped** plug-ins are closed, the scan of the shipped plug-ins reports 0 and
can guard the build like the core's scan does.

## Evidence

`specs/255-plugin-encoding-findings/verdicts.md` (the 78 rows) and `fix-log.md`; at the end of
feature 255 the scan reports 10 findings: 6 in shipped plug-ins (DB Viewer 1, Renamer 3 with
`shared/lukas`, UnISO 2 - the items this one depends on) and 4 in plug-ins that are off
(Automation 1, Multimedia Viewer 1, UnMIME 2).
`build.cmd` runs only `check_encoding.py --strict` (the core).

## Expected

`build.cmd` fails when a shipped plug-in (`plugins.cfg` on) has an unannotated finding, and passes
at the tree's state; plug-ins that are off are still reported, not failed.

## Approach

An option such as `--plugins --strict` that fails only on files of plug-ins that are on in
`plugins.cfg` (`shared/` counts as shipped), run by `build.cmd` next to the core's scan. Measure
with a negative control (one added sink line fails the build).

## Notes

Changes feature 239's "report only" requirement and the build gate - triage is the maintainer's.
Items for the plug-ins that are off (`automation-script-folder-list-code-page`,
`mmviewer-open-error-name-mojibake`, `unmime-progress-title-name-mojibake`) do not block it.

## Log

- 2026-10-20 — created (source leftover:255)
