---
title: checkver plug-in still checks Open Salamander's site: redirect it or drop it
type: decision
status: open
severity: 2
area: other-plugins
source: leftover:072
who: person
created: 2026-08-29
updated: 2026-10-26
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# checkver plug-in still checks Open Salamander's site: redirect it or drop it

## Problem

The legacy checkver plug-in still points at Open Salamander's (Altap's) site and is off in plugins.cfg. 072 recorded that winget handles updates for catalogue installs but nothing tells users who downloaded the installer from the website; the choice between the two ways out is a product decision, not code.

## Evidence

specs/072-winget-distribution/REMAINING-WORK.md, section P3. plugins.cfg line 17 'checkver=off' (at 7993914c). architecture/10-plugin-maintenance-outlook.md:90 (checkver points at Altap's servers; redirect to GitHub Releases API). Feature 123 (specs/FEATURE-HISTORY.md '- 123-new-version-check'): the core itself queries https://api.github.com/repos/tandemcommander/tandemcommander/releases/latest and notifies about a newer version. NEXT-WORK §6, P3 (L2044). Migrated from specs/NEXT-WORK.md §6 (at 7993914c).

## Expected

The maintainer has chosen; checkver is then either redirected (a feature) or removed from the tree and from architecture/10 (and plugins.cfg), with the update channel stated where users read it.

## Notes

NEXT-WORK gates the whole of its section 6 on microsoft/winget-pkgs#426090, but this decision touches no file under tools/winget/templates/ and does not wait for the PR (072 calls it "a product decision, not code"). Its premise changed after the source entry was written: feature 123 already covers website downloads. The recommendation below is the migrating agent's, from these facts; the source made none.

## Question

Should the checkver plug-in be pointed at the GitHub Releases API, or dropped, with winget and the program's own new-version notification (feature 123) declared the update channel?

## Options

- A — point checkver at the GitHub Releases API (architecture/10 lists it under 'maintain with modernisation').
- B — drop checkver (it is off in plugins.cfg anyway); updates come through winget for catalogue installs and through the core's notification of feature 123 for everyone else; say so on the website.

## Recommendation

B — feature 123 already checks GitHub Releases from the core, so a second checker would duplicate it and add a network claim to PRIVACY.md if ever enabled.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §5–§8 (feature 242)
- 2026-10-17 — unblocked
- 2026-10-17 — migration review S8: unblocked; #426090 mentioned only in Notes; migration remark removed
- 2026-10-26 — related item winget-submit-release-after-pr-426090 closed: done: #426090 merged 2026-10-08, 0.1.9, 0.1.10 and 0.2.0 submitted by the workflow and merged, the catalogue is current and works; maintainer 2026-10-26
