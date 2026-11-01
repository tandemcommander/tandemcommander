---
title: Should the settings import carry the new WSL option of the Change Drive page (374)
type: decision
status: open
severity: 1
area: panels-ui
source: leftover:374
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [check-by-hand-the-wsl-items-of-the-change-drive-menu-and-the]
depends-on: []
reason: -
---

# Should the settings import carry the new WSL option of the Change Drive page (374)

## Problem

Backlog item `change-drive-menu-and-drive-bar-have-no-wsl-item-for-the` (feature 374) asked for the
new option *Linux Distributions (WSL)* of the Change Drive configuration page to be "saved and
imported like `ChangeDriveShowNet`". Feature 374 saves and loads it (registry value
`Change Drive Show WSL`), and the program's own configuration export / import carries it, but it
is not on the allow-list of the settings import from Altap Salamander / Open Salamander.

## Evidence

- `src/cfgimport.cpp` (feature 245): the import table lists the old programs' values, e.g.
  `"Change Drive Network"`; `src/saltests/saltests.cpp` `TestCfgImport245` counts 112 entries and
  checks that none of Tandem Commander's own values is on it.
- Feature 245, spec FR-016: the import must not change Tandem Commander's own settings that have no
  counterpart in the old programs. The old programs have no WSL option.
- `specs/374-wsl-drive-item/fix-log.md`, *Decisions* (deviation); spec *Assumptions*; review 1
  NOTE 4 ("it is the maintainer's call").

## Expected

The maintainer confirms the deviation (then this item is closed) or asks for a change of rule 245.

## Question

Should the import of Altap Salamander / Open Salamander settings set the WSL option of the Change
Drive page?

## Options

- **A - no (as built).** The old programs never wrote such a value; rule 245 FR-016 stays as it is.
  An imported configuration keeps the WSL option at its default (on), or at what the user set.
- **B - yes.** Add an entry to the import table that sets the option, e.g. from the old
  `Change Drive Network` value; breaks FR-016 and the saltests count, and guesses a meaning the old
  programs never had.

## Recommendation

A - there is nothing in the old settings to import.

## Log

- 2026-11-01 — created (source leftover:374)
- 2026-11-01 — moved to Decisions for the maintainer
