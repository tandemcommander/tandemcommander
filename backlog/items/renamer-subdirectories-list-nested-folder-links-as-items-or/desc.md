---
title: Renamer subdirectories: list nested folder links as items or skip them
type: decision
status: open
severity: 3
area: data-safety
source: review:388
who: person
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Renamer subdirectories: list nested folder links as items or skip them

## Problem

Since feature 388 the Batch Renamer's "Include subdirectories" never walks a junction or a
directory symbolic link; it lists the link itself as an item (its name matched against the mask,
renamed by the rule), as backlog item `renamer-include-subdirectories-descends-into-junctions-and`
asked in its *Expected* and as the core's Change Case with subdirectories does (feature 213).
Plain subfolders, however, are walked and never listed in that mode. So with "Include
subdirectories" a rule such as `n_$(OriginalName)` renames the files below the selection and the
nested LINKS, but not the nested plain folders. The Renamer does not skip hidden / system entries:
selecting a user profile folder would list the old compatibility junctions (for example
`AppData/Local/Application Data`, `My Documents`) and a mask `*.*` would rename them. Before 388
these junctions stopped the listing with a "cannot read directory" box.

## Evidence

Review 1 of feature 388 (`specs/388-renamer-subdir-links/fix-log.md`, *Review*, SHOULD 1), by
reading `src/plugins/renamer/rendlg.cpp` `CRenamerDialog::LoadSubdir` (the branch on
`SalListedDirIsLink`) at branch `388-renamer-subdir-links`. Not driven on a real profile; whether
the ACLs of the compatibility junctions refuse their rename is not verified.

## Expected

The maintainer chooses how a nested link is treated with "Include subdirectories"; a run then
implements the choice (one small change in `LoadSubdir`, the probe rows of 388 adjusted).

## Question

With "Include subdirectories", should a junction / directory link found BELOW the selected folder
be listed as an item (renamed by the rule like a selected folder), or skipped silently like a
nested plain folder (neither walked nor renamed)?

## Options

- **A - keep 388's behaviour: list it.** Consistent with the core's Change Case / Change
  Attributes with subdirectories (213: the link's own entry changes) and with what the item asked.
  Cost: nested links are renamed while nested plain folders are not; hidden / system
  compatibility junctions in a profile can be renamed by a broad mask (the preview shows them).
- **B - skip it silently.** A nested link is neither walked nor listed, exactly like a nested
  plain folder is never listed; only a SELECTED link stays an item (the user chose it). Cost: a
  user who wants to rename links in a tree must select them; differs from the core's 213.
- **C - skip hidden / system links only.** List ordinary links (A), skip those with the hidden or
  system attribute. Cost: a rule of its own that neither the core nor the panel has.

## Recommendation

B: the Renamer's subdirectory mode is "rename the files of these folders"; a nested link is a
folder entry, and skipping it never renames something the user did not see selected. A selected
link stays an item (as 388 does).

## Log

- 2026-11-02 — created (source review:388)
- 2026-11-02 — related item renamer-include-subdirectories-descends-into-junctions-and done in feature 388
- 2026-11-02 — moved to Decisions for the maintainer position 9
