# Research: 251 - typed text is never cut to the caller's buffer

## R1 - Where the limit comes from

- Decision: the limit of each field is the buffer the program **loads and uses** the value with:
  `MAX_PATH` (260) for Make File List's name and line, user menu / viewers / editors Command and
  Initial directory, viewers / editors Arguments (`GetValue(..., MAX_PATH)` in `salamdr2.cpp`),
  hot path name, the drives' "go to" path, Edit New's default; `USRMNUARGS_MAXLEN` (32,772) for
  user menu Arguments; `HOTPATHITEM_MAXPATH` (1,040) for a hot path path.
- Rationale: a longer value would be cut when stored or, for the user menu, make the item fail to
  load at the next start (`mainwnd2.cpp`, the loader skips an item whose value does not fit).
- Alternatives: enlarging the buffers - changes what is stored and loaded (maintainer-owned:
  stored data) and does not remove the cut elsewhere; rejected.

## R2 - When pages that store on every keystroke refuse

- Decision: keep the whole text in the item (heap strings already) and refuse in the page's
  `Validate`, which runs on OK (`CTreePropDialog` `_TPD_IDC_OK`, `src/common/sheets.cpp`) and on
  leaving the page (`PSN_KILLACTIVE`).
- Rationale: the existing syntax checks of these pages run there; a keystroke cannot be refused;
  the page works on a copy, so Cancel leaves the configuration untouched.
- Alternatives: a per-item "too long" flag beside a cut value - the cut value would be shown and
  saved after switching items; rejected.

## R3 - The hot path code-page fallback

- Decision: read the whole text wide (`SalGetWindowTextU8Alloc`); no code-page read at all.
- Rationale: the fallback produced `?` for every character outside the code page (measured).

## R4 - Browse buttons

- Decision: refuse with the message and focus the field; no browse window.
- Rationale: the item's *Expected* ("each listed field ... refuses"); a cut path would start the
  browse elsewhere.

## R5 - The rule as a pure function

- Decision: `SalWTextFitsU8(const WCHAR*, int)` in `salunicode` (in `saltests` already).
- Rationale: CLAUDE.md working method - pure decisions with `saltests` checks; one definition for
  214's and this feature's checks.
