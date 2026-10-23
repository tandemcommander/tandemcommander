---
title: ISO plug-in: a fuzzing pass over the HFS+, ISO 9660, Joliet and Rock Ridge readers
type: tech-debt
status: new
severity: 5
area: other-plugins
source: leftover:322
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a fuzzing pass over the HFS+, ISO 9660, Joliet and Rock Ridge readers

## Problem

Backlog item `uniso-hfs-btree-trust-and-joliet-cut` (feature 223's leftover) asked for the HFS+
catalog walk to be bounds-checked **and** for "a fuzzing pass over HFS+ / ISO9660 / Joliet / Rock
Ridge" that finds nothing. Feature 322 did the bounds checks (the walk in `src/common/salhfscatalog.h`,
the record checks in `src/plugins/uniso/hfs.cpp`) and proved them with unit checks on catalogs built
in memory, each with one field out of range. The autonomous run did not generate mutated or damaged
disk images, so the fuzzing pass over the four readers of the ISO plug-in was not done.

## Evidence

- `specs/322-uniso-hfs-btree-joliet/fix-log.md`, section *Scope decision*; spec *Assumptions*
  (deviation, stop-rules §2.14).
- Readers: `src/plugins/uniso/hfs.cpp` (`CHFS::BTree::BTree`, `ListDirectory`, `UnpackFile`),
  `src/plugins/uniso/iso9660.cpp` (`ListDirectoryRe`, `ExtractExtFileName` - Rock Ridge SUSP / CE
  parsing of feature 223, `ConvJolietName`).
- Valid seed images: `specs/322-uniso-hfs-btree-joliet/probe/mkimg322.sh` (xorriso 1.5.6 in WSL:
  ISO 9660 + Rock Ridge + Joliet + HFS+ hybrid, Rock Ridge only, plain); the HFS+-only seed is the
  hybrid from offset 122880 (`iso322_probe.ps1`); IMAPI2 for Joliet.

## Expected

A fuzzing pass over the HFS+, ISO 9660, Joliet and Rock Ridge readers of the ISO plug-in (a
maintained fuzzing tool of the maintainer's choice, or a harness around the plug-in's readers) finds
no crash, out-of-bounds read or endless loop; what it finds is fixed by a bounds check in the reader
(refuse, never read outside the data).

## Notes

`who: person` - the maintainer decides how the pass is run (which tool, which harness, where the
mutated images live); an autonomous run of feature 322 deliberately made no such images.

## Log

- 2026-10-23 — created (source leftover:322)
- 2026-10-23 — related item uniso-hfs-btree-trust-and-joliet-cut done in feature 322
