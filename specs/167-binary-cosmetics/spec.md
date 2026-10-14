# Feature Specification: binary cosmetics of the 076 review

**Feature Branch**: `167-binary-cosmetics`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 17 (077; 076 review section 3.4, recommendation 6).

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A reviewer or a reputation system reads the shipped files: every binary built here names its
origin (utils\sqlite.dll had no version resource), carries Control Flow Guard, and the program
holds no dead anti-debug indicator.

## Requirements *(mandatory)*

- **FR-001**: utils\sqlite.dll has a version resource (SQLite's version, the product's).
- **FR-002**: every Release binary of the solution is built with /guard:cf (except one linked
  without the CRT, which cannot use it).
- **FR-003**: the dead SalGetProcessId is removed. No behaviour change.
