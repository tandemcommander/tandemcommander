# Feature Specification: the Portables information line in languages with accents

**Feature Branch**: `159-portables-infoline`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` 10b (found by 157's review).

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

Portables at the device level, a translated UI: the information line reads "1 vybrané zařízení"
(a device selected) and "Žádná zařízení" (none connected) whole.

**Independent Test**: by reading (the information line exposes no text); a person looks once.

## Requirements *(mandatory)*

- **FR-001**: Both texts are loaded as UTF-8 (`SplLoadStrU8`); no string, interface or registry
  change.
