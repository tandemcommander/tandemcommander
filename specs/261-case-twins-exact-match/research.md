# Research: case twins are addressed exactly (261)

## R1 - Compare Directories: which comparison in a case-sensitive folder

- Decision: a run of one first sort key (`RegSetStrICmpEx`) on both sides is paired as a set when
  either run holds a twin: byte-identical names first, then a name without a twin with the other
  side's name without a twin that is the same ignoring case; the runs of the comparison's copies
  are rearranged pairs first and the merge compares positions. Runs without twins keep
  `CmpNameExtIgnCase` (232).
- Rationale: fixes both directions (CMPTWIN1, CMPTWINR), also case-sensitive vs ordinary folder;
  keeps 232's pairing of `Readme.txt` / `README.txt` where no twin exists. The set pairing does not
  depend on an order, so it is consistent with the lists' sort order whatever the locale key
  treats as equal (a soft hyphen, NFC / NFD).
- Alternatives: the item's hint "`CmpNameExt` when both panels are case-sensitive" - misses a
  case-sensitive folder against an ordinary one and unpairs case-only singletons of two
  case-sensitive folders. The first version of this feature switched pair by pair between
  `CmpNameExt` and `CmpNameExtIgnCase` - the review (S1) measured a missed case-only pair beside
  twins in one locale run (soft hyphen); rejected.

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
