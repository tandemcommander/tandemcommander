---
title: UnCAB: a cabinet whose entry name is refused fails without any message
type: bug
status: open
severity: 4
area: archives
source: measure:381
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# UnCAB: a cabinet whose entry name is refused fails without any message

## Problem

When the UnCAB plug-in (shipped) refuses an entry name of a cabinet - a name flagged as UTF-8 that is not even WTF-8, a code-page name whose UTF-8 form does not fit, a too long next-cabinet name - its notify callback returns -1 and `FDICopy` ends with `FDIERROR_USER_ABORT`, for which `FDIError` shows **no message**. Enter on such a cabinet simply does nothing (the panel stays in the folder); Unpack (Alt+F9) extracts nothing, or only the entries before the refused one, and keeps the cabinet - all without a word. When some entries were already listed, the listing shows them as if the cabinet were complete ("we have already listed some files, so do not abort and display them" in `ListArchive`). The user cannot tell a refused name from a broken cabinet or from a click that did not register.

## Evidence

Measured by feature 381 (`specs/381-uncab-wtf8-name/fix-log.md`, *Measurement before*; probe `specs/381-uncab-wtf8-name/probe/cab381_probe.ps1`, rows U-BAD, U-OVER, L-BAD at bd7cc15e and after the fix): flagged names `a<FF>.txt` and `a<C0 80>.txt` -> nothing extracted, cabinet kept, "no window"; Enter leaves the panel in the folder, "no window". Code at 381's branch: `src/plugins/uncab/uncab.cpp` `CPluginInterfaceForArchiver::Notify` (`fdintCOPY_FILE` / `fdintPARTIAL_FILE`: `if (!CabNameToU8(...)) return -1;` without `Error(...)`), `FDIError` (`case FDIERROR_USER_ABORT: ret = 0;` - silent), `ListArchive` (`if (!ret && Count) ret = TRUE;`). The `fdintCABINET_INFO` / `fdintNEXT_CABINET` refusals do show `IDS_TOOLONGNAME` first.

## Expected

A refused entry name tells the user which entry (in a readable form, the bytes never guessed into another name) and why; an unpack that stops at it says so; a listing that is incomplete because of it is marked as incomplete. A real user abort (Cancel) stays silent.

## Approach

Show an error from the notify callback before returning -1 for a refused name (a new UI string - the `.slt` refresh of stop-rules §2.13), or skip the entry with a warning and continue, as the maintainer prefers; the fixture and probe of feature 381 already produce such cabinets.

## Notes

Out of scope of feature 381 (its item asked only that such a name "is still refused"). Whether to skip the entry or fail the cabinet is a behaviour choice; the conservative fix keeps the failure and only adds the message. The item `uncab-wtf8-flagged-name-refused` claimed the failure shows an "FDI error"; measured, it does not.

## Log

- 2026-11-01 — created (source measure:381)
- 2026-11-01 — moved to Next position 32
