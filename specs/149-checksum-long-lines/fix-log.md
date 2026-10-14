# Fix log: 149 - Checksum Verify takes a list line of any length

Backlog: `specs/NEXT-WORK.md` A.5 (queue 104 entry 4; 117 `fix-log.md`).

## Before (`probe/result_pre149.txt`, `Debug_x64` at `29c8bff4`)

Probe `probe/checksum_long_line_probe.ps1` (infrastructure of the 147 probe), row L1: a list with
`normal.bin` and `deep\<4 x 200 characters>\long.bin` (817 bytes relative, 858 with the list's
folder), both files matching: **"Cannot finish operation because of too long name."** and no
Verify window - not even the ordinary line was verified.

`ParseDigest` and `SalCslBuildPath` fail only when the output buffer is too small; both wrote into
`FILEINFO::fileName[3 * MAX_PATH]` / a `char path[3 * MAX_PATH]`.

## Work

- `dialogs.h`: `FILEINFO::fileName` is a malloc'ed `char*`, freed by a destructor.
- `dialogs.cpp` loader: the name buffer sized by the line (+ the list's name for the first-line
  fallback), the path buffer by the list's folder + the name; the item takes over the path; the
  former "too long" branch can now only mean low memory (`IDS_OUTOFMEM`).
- The Focus button: a path longer than `Focus_Path` (3 x MAX_PATH) is refused with the existing
  `IDS_TOOLONGNAME` instead of `lstrcpyn` cutting it.

## After

- Debug build clean; `saltests` 21,842 / 0; `check_encoding.py` TOTAL 0.
- `probe/result.txt`: L1 **PASS** - 2 rows, "All files OK", no box.
- Regressions: 117 `csumlist_probe` 82 / 0 (as recorded), 147 probe 7 / 0.

## Review (refute-first agent, 2026-10-14)

No defect in the change (buffer sizes, ownership and every branch checked). Taken over:

- MEDIUM: every newly admitted row had an EMPTY name - the list view's label buffer is 260
  characters and the conversion failed for a longer name (true before 149 for names of 260-779
  bytes too). `SetDispInfoText` now shows the end of the name with a leading ellipsis, cut at a
  whole character (no surrogate half). Not driven: reading the label needs the list view's own
  buffer in another process.
- Recorded (`specs/NEXT-WORK.md`): the core's `FocusNameInPanel` copies the folder and the name
  into `MAX_PATH + 200` buffers with `lstrcpyn` - a folder of 460-779 bytes is CUT (Focus from
  Checksum, and every plug-in that uses the service); the 149 guard refuses only from 780 bytes.
- LOW: the `IDS_TOOLONGNAME` box after `ParseDigest` cannot happen any more (dead, harmless);
  NIT: out-of-memory paths of the loader (pre-existing).

## Final

- `probe/result.txt` L1 PASS; 117 82 / 0; 147 7 / 0; `check_encoding.py` TOTAL 0.
