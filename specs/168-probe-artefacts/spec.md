# Feature Specification: probe artefacts on the hidden desktop

**Feature Branch**: `168-probe-artefacts`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 18: find the mechanism of the 093 Find-menu flake and the
088 viewer rows before trusting them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A developer runs the 093 and 088 probes on the hidden desktop and gets the same verdict every
time; a FAIL means the program, not the desktop.

## Requirements *(mandatory)*

- **FR-001**: the mechanism of each artefact is measured and written down; the probe is
  corrected, not the program.
- **FR-002**: a product behaviour seen on the way is recorded in NEXT-WORK.
