---
title: A refused configuration file does not say which key is outside the program root
type: improvement
status: new
severity: 3
area: panels-ui
source: leftover:263
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# A refused configuration file does not say which key is outside the program root

## Problem

Since feature 263 the start-up import of a configuration file (config.reg next to the exe, in
%APPDATA%\Tandem Commander, or the -C file) refuses the whole file when one key or delete line is
outside HKEY_CURRENT_USER\Software\Tandem Commander\0.1, with the generic "Unable to import the
specified file. It is not a configuration file." The user (often an administrator who edited the
file, as the help invites) is not told which line caused it, and the help page does not say that
only the program's own key may be in the file.

## Evidence

- `src/salamdr2.cpp` `ImportConfiguration` at the feature 263 commit: `RPE_KEY_OUTSIDE_ROOT` and the
  no-key case are reported with the existing `IDS_IMPORTCFG_NOTREG`; the offending line goes only to
  the trace log (`TRACE_E` in `Parse`, `src/reglib/src/regparse.cpp`).
- `specs/263-import-foreign-reg-keys/spec.md` *Clarifications*: naming the key needs a new UI
  string, which a run cannot add (translation refresh, rule 084).
- Review 2 of feature 263 (`fix-log.md`, *Review 2*, NOTE):
  `help/src/hh/salamand/customize_configuration.htm` tells administrators they can change the file to
  suit their needs; a file that also sets one foreign key (file associations) is now refused at every
  start.

## Expected

The refusal names the first key outside the root (whole, never cut - a heap buffer) and says that a
configuration file may hold only the program's own key; the help page
`customize_configuration.htm` states the rule. A new UI string: the two-stage `.slt` refresh is
needed (rule 084).

## Notes

- Needs the maintainer's translation refresh after the string is added, so an autonomous run would
  stop at it; the maintainer may prefer to do it together with other string changes.
- `Parse` would have to hand the offending line back to the caller (an out parameter), since the
  message box is shown by `ImportConfiguration`.

## Log

- 2026-10-20 — created (source leftover:263)
