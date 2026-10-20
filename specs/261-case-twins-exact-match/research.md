# Research: case twins are addressed exactly (261)

## R1 - Compare Directories: which comparison in a case-sensitive folder

- Decision: twin-aware - byte-exact (`CmpNameExt`) only for names whose first sort key is equal
  and where either side has a twin; otherwise `CmpNameExtIgnCase` (232).
- Rationale: fixes both directions (CMPTWIN1, CMPTWINR), also case-sensitive vs ordinary folder;
  keeps 232's pairing of `Readme.txt` / `README.txt` where no twin exists. The merge stays
  consistent: when one run holds twins, every comparison of a twin uses the strict order, which
  is exactly the sort order of both lists; a run without twins on either side keeps the 232
  comparison. (A run mixing twins with names equal only by the locale / numeric first key -
  "a01" / "a1" - can mix both modes; the merge still advances on every step and pairs only names
  the chosen comparison calls equal.)
- Alternatives: the item's hint "`CmpNameExt` when both panels are case-sensitive" - misses a
  case-sensitive folder against an ordinary one and unpairs case-only singletons of two
  case-sensitive folders (a 232 behaviour change the item does not ask for). Pairing exact twins
  first inside a run and then the remainder loosely - picks an arbitrary twin for the remainder
  (spec Clarification 2: never).

## R2 - Lookups by name (viewer, User Menu, Ctrl+X)

- Decision: byte-identical item first; else the single `SalNameEqualOrdinalCI` match; two or more
  such matches: none.
- Rationale: the names come from the panel itself (exact bytes), so the exact item is there; the
  fallback keeps today's behaviour for a name the user or another program changed in case only
  (spec Clarification 1). Same shape as feature 230 without the case-sensitive-folder exclusion
  (230 handled names supplied by an outside drag source).
- Alternatives: the panel's `IsCaseSensitive()` rule (strict in case-sensitive folders) - changes
  behaviour without twins; first exact else first CI - still picks an arbitrary twin.

## R3 - Remembered folder sizes (`CDirectorySizesHolder`)

- Decision: no change. Its only `Store` / `Restore` calls are commented out
  (`fileswn8.cpp` "//            DirectorySizesHolder.Store(this)", `fileswn3.cpp` "// to
  DirectorySizesHolder.Restore(this)"); `Get` has no caller. Unreachable (Measure first).

## R4 - Turkish / Azeri locale

- Decision: out of scope; own Inbox item. `RegSetStrICmpEx` is the panel's sort key; making it
  treat dotted / dotless i as one letter would change the sort order of every panel - a separate
  decision (the item's Notes: possibly to park).
