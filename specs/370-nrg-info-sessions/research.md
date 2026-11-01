# Research - feature 370

## R1 Where the session table is read

- Decision: only `CISOImage::DumpInfo` (`viewer.cpp`) changes.
- Rationale: readers of `Session` enumerated (Grep `Session[`, `Session.Count`): `img.cpp` (CCD layout,
  checked by feature 352's `SalIsoCcdLayoutTrusted`), `isoimage.cpp` `ListTracks` (feature 340,
  `SalIsoSessionTracks`), and `viewer.cpp` `DumpInfo` - the only unguarded one. Writers: `nrg.cpp`
  `readSINF` (one SINF chunk a session, unsigned DWORD stored as `int`), `img.cpp` (CCD, counts from the
  track table - always covers it), `isoimage.cpp` plain detection (`Session.Add(1)` with one track).
- Caller of `DumpInfo`: `uniso.cpp` `CPluginInterfaceForViewer::ViewFile` (F3 / View on the image file,
  default viewer association `*.nrg` etc.) - a temporary file handed to the internal viewer as
  `iso_dump.txt`.

## R2 How the dump walks the tables

- Decision: walk the sessions (`for s < Session.Count`), each getting
  `SalIsoSessionTracks(first, (unsigned int)Session[s], Tracks.Count, fits)` tracks, `first += n`; then
  the tracks `first .. Tracks.Count - 1` under the new line, printed only when any are left.
- Rationale: the same rule the listing uses (feature 340); never reads `Session` past `Count`; a count
  of 2^31 or more is read unsigned and limited to the tracks left; a 0 count shows the session with 0
  tracks instead of putting the next tracks under it.
- Alternatives: guard `session < Session.Count` in the old track walk - keeps the wrong attribution of
  0 and negative counts (S-NEG, F-ZERO), rejected.

## R3 What "Number of tracks" shows

- Decision: the tracks the session gets (`n`), not the declared count.
- Rationale: consistent with the tracks listed under it; `%d` in all translations stays valid (a
  declared count above 2^31 would need `%u` - a changed format in every language).

## R4 The new line

- Decision: `IDS_INFO_NO_SESSION` = 1157, `"\nTracks not in any session\n"`, in the free slot of string
  bundle 72 (1152..1167, used 1152..1156) - rule 084, no renumbering.
- Translation: two-stage `.slt` refresh of module `uniso` (stop-rules 2.13), formal register.

## R5 Measurement

- Probe `probe/iso370_probe.ps1`: F3 via `WM_COMMAND 742` on the focused image; the viewer's text is
  read from the disk cache (`iso_dump.txt` in a folder under `%TEMP%`, written in this row) while the
  viewer is open. Before (2c1c1279): PASS 6 / FAIL 10 (`result_before.txt`).
