# Research - 316 Unpack keeps the leading space of a relative target

## R1 Where the space is lost

- Decision: in `SalGetFullName` (`src/salamdr3.cpp`), relative branch: `s` points after the
  leading characters <= ' ', and `memmove(name + l2, s, l1 + 1)` joins `curDir` with the name from
  `s`; with `allowRelPathWithSpaces` TRUE and `*s != '\\'`, `s = name` first, so the spaces stay.
- Rationale: measured (probe rows space-sd, space-sd-long, space2-sd, typed-space unpacked into the
  folder without the space at b125acf7) and read.
- Alternatives considered: changing `SalGetFullName`'s default - rejected: 25+ core callers and the
  plug-in service `CSalamanderGeneral::SalGetFullName` rely on the trimming (constitution II, V).

## R2 Create the folder with the space, or refuse

- Decision: keep the existing create rule: `CFilesWindow::Unpack` calls `CheckAndCreateDirectory`
  with `manualCrDir = TRUE`, which refuses a new component starting with a character <= ' '
  (ERROR_INVALID_NAME; upstream comment: leading spaces are undesirable for folders created at the
  user's request). An existing folder is used without that check.
- Rationale: the item allows "or the program refuses with a message"; the absolute entry
  `<other panel>\ ssss` already gets this refusal (probe row ctl-abs-space at b125acf7), so both
  entries of the same dialog now behave alike; no new string.
- Alternatives considered: `manualCrDir = FALSE` for Unpack - creates the folder with the space;
  changes an existing rule for the absolute entry too, which the item does not name - rejected
  (conservative).

## R3 Other consumers after the call

- `nextFocus`: `SalGetFullName` copies `name` (with its spaces) into it before joining - it named
  ` ssss` already; now it matches the folder used.
- `SalUnpackEmptyTarget` (feature 315): reached only for IDS_EMPTYNAMENOTALLOWED; an entry of
  spaces only still ends there (the emptiness test runs on `s` before the relative branch).
- Drive-letter (`  C:\x`) and root-relative (`  \x`) entries take other branches, unchanged.
- `ExecuteUnpacker` gets an absolute path whose component starts with a space only when that folder
  exists; a space inside an absolute path is ordinary for the ZIP plug-in (probe row
  space-sd-exists).

## R4 Same defect elsewhere

The Pack dialog (`fileswn2.cpp`, archive name) and other `SalGetFullName` callers also trim a
relative name; out of scope (item names Unpack) - recorded in `fix-log.md`.
