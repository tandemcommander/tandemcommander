# Feature Specification: Portables "N selected devices" takes its plural

**Feature Branch**: `161-portables-plural`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` 10c (found by 159's review, upstream).

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

Portables at the device level, devices selected: the information line reads "2 selected
devices", in Czech "2 vybraná zařízení" / "5 vybraných zařízení", in every enabled language its
own plural.

**Independent Test**: `probe/plural161.py` - a port of `ExpandPluralString` run over the patterns
of the eight languages (the information line exposes no text; a person step).

## Requirements *(mandatory)*

- **FR-001**: `IDS_SELECTEDDEVICEFMT` names the parameter it has; each translation its own plural
  pattern (pinned in `translations/ui-overrides.json`).
