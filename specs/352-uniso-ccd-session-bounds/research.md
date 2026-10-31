# Research - 352

## R1 What a refused .ccd does today

- Decision: keep it - `IDS_CCD_BAD_FORMAT` ("Bad format of .CCD file. Displayed image could be
  incomplete."), `ReadSessionCCD` returns FALSE, `Open` falls back to plain detection
  (`DetectSectorType`, `CheckForISO`, ...) - and add the listing mark.
- Rationale: the plain detection reads the first session's file system only; a whole unpack with
  "Delete archive after unpacking" would then delete a multi-session image whose later sessions were
  never listed. The box already says the image could be incomplete; the mark makes the whole unpack
  fail (328's `ListingLeftOut`), so the image is kept. No new text.
- Alternatives: refuse without fallback (the image does not open at all - more change than needed);
  ignore a bad entry and go on (guesses a geometry from a damaged table).

## R2 Sections and splits that disagree

- Decision: open within bounds, mark the listing incomplete, no box.
- Rationale: by the related item's reading of libmirage, a real multi-session CloneCD dump has
  absolute `INDEX 1` values: two sections, one split. Refusing it would make such images fall back
  to the plain detection (first session only). Today it hits `Session[1]` past the split list (Debug:
  TRACE_C, measured R-ABS) - undefined in Release.
- Alternatives: refuse (see above); fix the split geometry (the related item's job, out of scope).

## R3 Parsing

- Decision: a needed row counts when its value has a number as `sscanf("%d")` / `sscanf("%x")` would
  read it (blanks, sign, `0x` for hex, digits; trailing text ignored) and fits 32 bits; each needed
  row exactly once.
- Rationale: valid files read exactly as before; "no number" (`MODE=x`, empty) and duplicated rows
  were the uninitialised-value cases (measured R-MODEX, R-DUP). A hand-written parser keeps the header
  free of the CRT (`sscanf` deprecation warnings in saltests) and refuses overflow, which `sscanf`
  leaves undefined.
- Alternatives: keep `sscanf` and check its result (works, but overflow undefined, CRT in a header).

## R4 Entry session range

- Decision: `1 <= Session <= number of [Session n] sections`, compared as `int` (no `BYTE`), checked
  for all entries before any table is touched; outside -> the `.ccd` is refused (R1).
- Rationale: FR-001; `Session=257` was taken as 1 through the byte (measured RTC #1 in Debug).
