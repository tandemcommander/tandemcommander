# Research - 382-arc-case-twins-path

## R1 - Where to fix: the lookup of a typed path, not the listing's rule

- Decision: resolve the typed path in `ChangePathToArchive` before the shortening loop.
- Rationale: `SalDirStrCmp` / `SalDirStrCmpEx` are used by the listing's build (`AddDir` merges,
  `GetFiles`, `GetDirs`, `GetIndex`), by refresh and by the "same path" checks; making them
  per-folder case-insensitive would merge or confuse twins again (the defect of 252). Only the
  user's typed path needs leniency.
- Alternatives: a per-folder case rule (only folders with twins compare exactly) - needs the
  listing to know which folders hold twins (plug-in flag is listing-wide; would need a core
  re-scan or an ABI addition, the ABI is maintainer-owned) and changes every consumer. Rejected.

## R2 - Which comparison accepts a folder, which counts ambiguity

- Decision: accept = the legacy byte fold `StrICmpEx` (what a listing without twins uses to find
  folders, so the folder opened is the one the same archive without twins opens, 273); ambiguity =
  siblings equal by `StrICmpEx` **or** `SalNameCompareOrdinalCI` (the two rules of
  `salcasetwins.h` that decide twins). Accept only when exactly one sibling is equal by either
  rule and that sibling is fold-equal.
- Rationale: never open one twin for a name that also fits the other; never accept more than
  273 accepts for a twin-free archive.
- Alternatives: ordinal only (would accept names 273 does not); fold only for ambiguity (could
  miss twins the ordinal rule sees, e.g. Unicode letters). Rejected.

## R3 - Exact match first, also in a case-sensitive listing

- Decision: an exact component always wins (first equal by the listing's comparison, as
  `GetFiles`), the loose step only when no exact folder exists and the folder is case-sensitive.
- Rationale: keeps 252 / 273 behaviour (EXACT row: `DOCS` opens `DOCS` beside `Docs`).

## R4 - Partial resolution

- Decision: resolve leading components while they resolve; copy the rest verbatim.
- Rationale: the existing loop then shortens a missing tail and focuses a file name as before
  (MIXMISS row: `DOCS\nothing` -> `Docs`; `DOCS\F.TXT` keeps its file-focus behaviour).

## R5 - Placement before the "same path" check

- Decision: resolve right after `path` is computed, before
  `sameArch && SalDirStrCmp(path, GetZIPPath()) == 0`.
- Rationale: with a case-sensitive listing and the panel already at `Docs`, typed `DOCS` would
  otherwise fail that check, resolve later and hit the "shortened path equals the current one"
  exit (returns FALSE, CHPPFR_SHORTERPATH). Resolving first makes it the plain "same path" refresh.

## R6 - Length and buffer

- Decision: output into a `char[MAX_PATH]` (as `path`); fold-equal names have equal byte length
  (`StrICmpEx` returns 0 only for equal lengths), so the result has the typed length; the template
  still checks the size and refuses (typed path kept) - never cuts.
