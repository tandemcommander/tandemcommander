# Research - 359-uniso-udf-vat-cut

## R1 - Is the item's trigger a hang?

- Decision: no, not as stated; the hang is real by another path.
- Rationale: in a `do { ... continue; ... } while (vatLoc < lastVatLoc && ...)` loop, `continue` evaluates the
  condition. With `nSectors < 7` the fallback sets `vatLoc = nSectors - 7` (wrapped, ~4 * 10^9) and
  `lastVatLoc = nSectors` (small): the condition is false, the loop ends with `ERR_CONTINUE` ("Missing virtual
  allocation table."). Measured (probe rows L-CUT3, R-CUT3, L-CUT0 at 13bcb6a1). The loop repeats only when a
  read fails at a fallback sector below 7 (then `vatLoc - 7` wraps and is larger than `nSectors`): measured
  with a raw Mode 1 dump (L-RAWCUT, R-RAWCUT - main window not answering).
- Alternatives considered: fixing only the `nSectors < 7` arithmetic - would leave the repeat path.

## R2 - Why do fallback reads fail?

- Decision: the file's sectors are counted as bytes / 2048 (`CISOImage::GetCurrentTrackEnd` returns bytes of
  the track); a raw dump has 2352-byte sectors, so the count is about 15 % too high and the fallback window
  lies past the file's end.
- Rationale: `CISOImage::ReadBlock` maps a sector through `GetSectorOffset` (`SectorRawSize`), so reads past
  the real end fail.
- Scope: counting in the real sector size is a separate defect (whole raw VAT dumps do not open, row
  L-RAWFULL) - Inbox item, not this feature.

## R3 - The rule

- Decision (first version; review 1 moved it to track sectors - below): `SalIsoUdfVatFallback(fileSectors, partStart, failed, taken, first, last)`, 64-bit:
  - `taken` -> false (at most once);
  - `fileSectors <= partStart` -> false (no partition sector in the file: the read error at once);
  - `n = fileSectors - partStart`; `n + 7 >= failed` -> false (today's `nSectors < vatLoc - 7`, without wrap);
  - else `first = n >= 7 ? n - 7 : 0`, `last = n`, true.
- Since `n + 7 < failed <= 0xFFFFFFFF`, `first` and `last` fit the plug-in's 32-bit `vatLoc`.
- Review 1 (S1): decided in track sectors - `SalIsoUdfVatFallback(trackSectors, partStart, extentOffset, failed,
  taken, first, last)`: the failed read's track sector `(partStart + failed) mod 2^32`, the partition's start in
  the track `partStart - extentOffset` (0 when smaller), the window `[max(T - 7, start), T)` mapped back by
  subtracting `partStart` mod 2^32, a window that would cross position 0 clipped to start at `partStart`.
- Alternatives considered: an iteration counter in the loop (bounds the hang but keeps the wrapped numbers).

## R4 - Callers

- `ReadSupportingTables` <- `CUDF::Open` only; `CUDF::Open` <- `CISOImage::OpenTrack` (fsUDF) and
  `CUDFISO::Open` (hybrids). A FALSE return is the existing "not opened" path of feature 358 (`VatMissing`).
- `GetCurrentTrackEnd` is called only here (Grep).
