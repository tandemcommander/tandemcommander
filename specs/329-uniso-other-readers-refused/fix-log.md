# Fix log - feature 329 (backlog item iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses)

## Measurement before the fix (main aa939af0, branch at 61c5a0b5 - no code changed)

Code trace: ListArchive -> `CISOImage::ListImage` -> `CUDFISO::ListDirectory` (ISO 9660 / UDF / HFS+
parts of a hybrid) or `CUDF` / `CXDVDFS` / `CHFS` / `CAudio::ListDirectory`. The sites of the item are
unchanged since 328 (research R5 left them):

- `udf.cpp` `CUDF::AddFileDir`: a refused `AddDir` / `AddFile` -> `Error(IDS_ERROR)`, FALSE (fd.Name
  leaked); `ScanDir` returns `ERR_TERMINATE`, the parent turns it into `ERR_CONTINUE` and "descend
  only when everything is OK" skips every later folder of the walk.
- `xdvdfs.cpp` `CXDVDFS::AddFileDir` / `ScanDir`: the same with `return ERR_CONTINUE` (the rest of the
  folder dropped).
- `hfs.cpp` `CHFS::ListDirectory`: `Error(IDS_ERR_TOO_LONG_PATH)`, `return FALSE` - every later catalog
  record dropped. A plain "continue" would not do: a child whose parent folder is not in `pFolders`
  falls back to the HFS+ root path (`path = rootPath`).
- `audio.cpp` `CAudio::AddFileDir`: `dir->Clear(pluginData)` + "Error".
- `uniso.cpp` `UnpackWholeArchive` fails only when `CPluginDataInterface::ListingLeftOut` is set -
  set only from `CISOImage::ListingLeftOut.Incomplete`, which only the ISO 9660 reader fills.

Probe `probe/iso329_probe.ps1` (new; seeds by `probe/mkimg329.sh` in WSL - genisoimage `-udf`,
xorriso `-hfsplus on` - and `probe/img329.py` - an XDVDFS image and a two-track audio NRG), on the
Debug build of the branch start (= main):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc329_log_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe>\iso329_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile <probe>\result_before.txt"
```

-> `probe/result_before.txt`: **RUN rows PASS 0 / 7**:

- U-COPY / U-UNP-DEL (UDF part of the hybrid): "UnISO: Error" at the open; `UDF (TC329)` holds only
  `a<59x>\side.txt`, `top.txt` - `zlast\z.txt` lost; the unpack with "Delete archive after
  unpacking" deleted the image.
- X-COPY / X-UNP-DEL (Xbox): the same ("Error", z.txt lost, image deleted).
- H-COPY / H-UNP-DEL (HFS+ part of an xorriso hybrid): "This disk image contains a too long path
  ...", z.txt lost, image deleted.
- A-OPEN (audio NRG, 2nd track labelled 253 x L): "Error", the listing empty (Select All: "No
  matches found").
- END rows of the U / X runs: ~135 "Detected memory leaks!" boxes at exit (Debug heap) - compare
  after the fix (the refused path leaks `fd.Name`).
- "Cannot read sector #00000020" at the open of the HFS+ hybrid: known, Inbox item
  `iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot` (322 / 327) - not this feature.

## speckit-analyze

- Run 1: 0 CRITICAL / HIGH; MEDIUM I1 (SC-001 still said "audio, when the crafted image opens") fixed
  in spec.md; LOW U1 (T009's negative control is the before run, result_before.txt 0 / 7) accepted -
  the independent review builds its own negative control.
- Run 2 (after the fix): 0 findings above LOW.

## The change

- `src/common/salisonamefit.h`: `CSalLeftOutIds` - the catalog IDs of left-out folders (sorted vector;
  `Add` false on out of memory). saltests `TestIsoLeftOut329`: the probe trees' decisions (UDF / HFS+
  folder part 256 bytes refused, Xbox `deep.txt` under 305 bytes refused, the audio name of 256 bytes
  refused and `01 SHORT` taken) and the ID set (found / not found, duplicates, a 101-folder chain).
- `udf.cpp` / `udf.h`, `xdvdfs.cpp` / `xdvdfs.h`: `AddFileDir` returns 328's `ADD_FAILED` /
  `ADD_LISTED` / `ADD_LEFT_OUT`; the listing's rule is asked first (no allocation for a refused
  entry - the old path leaked the name); out of memory and the core refusing after the rule mark
  `ListingLeftOut` incomplete; `ScanDir` descends only a listed folder and goes on with the next
  record. A UDF read error (`MapICB`) still ends the directory (Inbox item for read errors).
- `hfs.cpp` `CHFS::ListDirectory`: a record whose parent is a left-out folder is skipped (a folder's
  ID added); a refused folder is recorded, its ID added, the walk goes on; a refused file is
  recorded; the core refusing after the rule: incomplete + "Error"; every out-of-memory exit marks
  the listing incomplete. `IDS_ERR_TOO_LONG_PATH` is no longer shown (the string stays, R6).
- `audio.cpp` `CAudio::AddFileDir`: a refused name is recorded, TRUE; never `Clear`.

## Checks after the fix

- `build.cmd` -> BUILD SUCCEEDED (C4267 warnings at `fd.NameLen = strlen(...)` are the readers' old
  lines, the same as iso9660.cpp's).
- `saltests.exe` -> `saltests: 28233 checks, 0 failed`.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe after (`probe/result_after.txt`): **RUN rows 7 / 7 PASS** (14 / 0 with the END rows), registry
  restored and identical. The UDF / HFS+ report names `UDF (TC329)\a..\b..\c..\d..\e<59x>` /
  `HFS (TC329)\...\e<59x>`, the Xbox one `a..\...\e<59x>\deep.txt`, the audio one `02 L...`; no
  `deep.txt` anywhere in the HFS+ part (FR-006); all three unpacks keep the image; the audio Copy
  answers "Audio tracks cannot be extracted" for `01 SHORT`. The ~135 Debug-heap "Detected memory
  leaks!" boxes of the U / X rows are gone (the refused name is no longer allocated).
- First after run: A-OPEN FAIL on the probe's own match - the box wraps the 253 letters and the
  window-text helper joins the lines with a space; the match now ignores the whitespace (the before
  run still fails A-OPEN: "Error", no "(206)", nothing listed).
- Regression probes on the fixed build: `iso328_probe` 20 / 0 (`probe/regress_328.txt`),
  `iso327_probe` 77 / 0 (`probe/regress_327.txt`), `iso322_probe` 18 / 0 (`probe/regress_322.txt`) -
  every registry restored and identical.
- Known, not this feature: "Cannot read sector #00000020" at the open of the HFS+ hybrid (Inbox item
  `iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot`).

## New Inbox items

- `iso-plug-in-an-nrg-audio-track-label-of-257-bytes-overruns-a` - `CAudio::ListDirectory` formats the
  track name with `sprintf` into `char[MAX_PATH]` (research R5), not measured.

## Review

### Review 1 (independent refute-first agent, on 2abc8895) - no MUST

Its runs: the feature's probe 14 / 0; a negative control (only `uniso.spl` rebuilt from HEAD~1) 0 / 7
RUN rows (the image deleted in all three unpacks); a mutation with the HFS+ skip of a left-out
folder's contents switched off - H-COPY / H-UNP-DEL FAIL (`deep.txt` at the HFS+ root); a deeper tree
(`e/f/g.txt`, `e/f/h/hh.txt`) passes; saltests 28233 / 0. Callers enumerated (`AddFileDir` of the
three readers, `ListImage` / `ListArchive`, `ListingLeftOut` read only in uniso.cpp); the readers'
rule matches the core's `AddFile` / `AddDir`; no double free; paths bounded; reports never cut.

- SHOULD 1 - SC-003 claimed more than saltests check: the HFS+ "skip under a left-out folder, keep a
  skipped folder's ID" decision was inline in hfs.cpp. **Fixed**: `CSalLeftOutIds::Under` in
  `salisonamefit.h` (results `SAL_ISO_UNDER_LISTED / SKIPPED / NO_MEMORY`), hfs.cpp calls it;
  saltests walk a simulated catalog of the probe's tree + `e/f/g.txt`, `e/f/h/hh.txt` (listed /
  reported / skipped names). Negative control: `Under` without keeping a folder's ID -> saltests 2
  failed (listed and skipped lists); restored -> 28266 / 0.
- SHOULD 2 - the probe tested one level below the left-out HFS+ folder. **Fixed**: `mkimg329.sh`
  adds `e<59x>/f/g.txt` and `e<59x>/f/h/hh.txt` (UDF and HFS+ seeds); the exact-3-files check guards
  them. `probe/result_after_review1.txt`: 14 / 0.
- NOTE 3 - HFS+ catalog order: a folder whose ID is lower than its parent's lists its contents at the
  root (old code; also defeats FR-006 for such a folder) -> Inbox
  `iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent` (review:329).
- NOTE 4 - UDF `MapICB` failures, HFS+ records of other types and feature 322's skips do not mark the
  listing incomplete -> Inbox `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let` (review:329;
  related to the ISO 9660 read-error item).
- NOTE 5 - audio.cpp freed a `DupStr` name with `free()` in the function this feature changed ->
  **fixed** (`SalamanderGeneral->Free`).

After the fixes: `build.cmd` BUILD SUCCEEDED; saltests 28266 checks, 0 failed; encoding guard
TOTAL: 0; probe 14 / 0 (`probe/result_after_review1.txt`). No MUST finding, so no second review round.
