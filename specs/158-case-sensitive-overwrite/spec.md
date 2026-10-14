# Feature Specification: a case-sensitive folder offers the overwrite of another file

**Feature Branch**: `158-case-sensitive-overwrite`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 11 (103, 106, 119): "A case-sensitive folder refuses `a.txt` ->
existing `A.txt` although it is provably another file (could offer the overwrite)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Renaming onto a different-case name of another file (Priority: P1)

In a case-sensitive folder (WSL, `fsutil setCaseSensitiveInfo`) `a.txt` and `A.txt` are two files.
Renaming `a.txt` to `A.txt` (Quick Rename or F6) asks whether to overwrite `A.txt`, as for any
other existing file; Yes replaces it, No keeps both. One file under two names (hard links) is
never "overwritten by itself".

**Independent Test**: `probe/cs_overwrite_probe.ps1`.

## Requirements *(mandatory)*

- **FR-001**: The overwrite question only when the file system's identity PROVES another file
  (volume serial + file id differ); unknown identity keeps the refusal.
- **FR-002**: No string, interface or registry change.

## Decision

Taken by the agent under the maintainer's "fix all items" (the item was recorded as "a behaviour
change left for a decision"): the overwrite is offered only on proof; the maintainer may reverse it.
