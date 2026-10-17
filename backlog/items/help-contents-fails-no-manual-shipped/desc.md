---
title: Help > Contents ends in a Help Error box: the product ships no manual
type: decision
status: open
severity: 4
area: help-docs
source: measure:080
who: person
created: 2026-09-20
updated: 2026-10-17
verified: 2026-10-17 7993914c
effort: ?
feature: -
related: [codeview-limitations-not-stated-for-users]
depends-on: []
reason: -
---

# Help > Contents ends in a Help Error box: the product ships no manual

## Problem

The shipped product contains no help files: `help\` is not in the Release tree or the installer, so *Help > Contents* (also the toolbar's help button and the Find window's help command, `CM_HELP_CONTENTS`) ends in a *Help Error* box, in every release. The manual's sources exist (`help/src`, an HTML Help project `salamand.hhp`) but are not rebranded - 236 of 237 pages still carry the 2023 Open Salamander footer.

## Evidence

specs/080-restart-manager-upgrade/REMAINING-WORK.md, *Found on the way, not part of this feature* (L110-112): "*Help -> Contents* ends in a *Help Error* box. Known in spirit (the help is not rebranded yet), but worth stating plainly." At 7993914c: setup/tandemcommander.iss has no help entry; `CM_HELP_CONTENTS` handled in src/mainwnd3.cpp ~2987 and src/finddlg1.cpp ~3946, toolbar button src/toolbar4.cpp:204. Not in specs/NEXT-WORK.md at 7993914c (only the footers, *Recorded, deliberately not on the list*).

## Expected

(not stated in the source)

## Notes

Context-sensitive F1 in dialogs was not checked. The old footer of the help pages is the parked item `help-pages-carry-2023-open-salamander-footer`.

## Question

What should the Help commands do while the product ships no manual?

## Options

- A - build the manual from `help/src` as it is and ship it with the installer (Open Salamander text and footers included).
- B - rebrand the manual first (a feature series), then ship it.
- C - until a manual ships, make the Help commands say plainly that no manual is installed (or open the project's website) instead of the Help Error box.

## Recommendation

C now (removes the error box at little cost; a website link would be new network-facing behaviour - PRIVACY.md), B when a manual is wanted. A suggestion of the migration, not decided.

## Log

- 2026-10-17 — migrated from specs/*/REMAINING-WORK.md (feature 242)
- 2026-10-17 — migration review N3: cross-reference to the final slug
