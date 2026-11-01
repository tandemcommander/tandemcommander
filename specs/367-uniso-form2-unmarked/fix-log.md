# Fix log - 367-uniso-form2-unmarked

Backlog item `iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa` - ISO plug-in: a video file in Form 2
sectors without an XA Form 2 attribute extracts cut.

## Measurement before (main 56a44fba)

- `.\build.cmd` (Debug x64) - BUILD SUCCEEDED.
- Images: `python -I specs/366-uniso-form2-files/probe/img366.py %TEMP%\rev335c\data %TEMP%\tc367img` (the real
  vcdimager 2.0.1 output 366 used, still in `%TEMP%\rev335c\data`).
- Probe (hidden desktop): `iso366_probe.ps1 -ImgDir %TEMP%\tc367img -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1
  -Label before-367 -Only C-MIXED,C-NOXA,C-F1SUB` -> PASS 6 against 366's expectations, which are main's
  behaviour for these rows: C-MIXED and C-NOXA extract `MPEGAV/AVSEQ01.DAT` as 608,256 bytes, C-F1SUB
  `MPEGAV/AVSEQ02.DAT` as 608,256 bytes - the 2048-byte read of 297 sectors (366 measured the 2324-byte read,
  690,228 bytes, holds `v.mpg` whole and the 2048-byte read does not); the image deleted in all three
  ("image kept: False"). Registry restored, identical. The defect is present and reachable (whole Unpack,
  default configuration, uniso on).

## Approach chosen

The item's first alternative - read whole, decided per sector by the subheader. Every case is decidable at
listing; the fail-closed alternative is the one the open decision `keep-video-cd-images-after-a-whole-unpack-until-their-video`
governs (the item's Note), so it is not implemented. Details: `research.md` R1-R5.

## Sites and consumers (enumerated)

- `CFilePos::Form2` (isoimage.h) - set: `CISO9660::AddFileDir` (366); read: `CISO9660::UnpackFile`,
  `CRawFS::UnpackFile`, `CISOImage::NoteListedFileStarts`. No other reader (Grep `Form2` in `src/plugins/uniso/`).
- `CISO9660::AddFileDir` callers: `ListDirectoryRe` files (366's XA attributes; the only path examined now), its
  folder branch (folders never examined), the boot record (`AddBootRecord`: a virtual record - not examined,
  default argument).
- `SalIsoSectorIsForm2` callers: `CISOImage::Open` (335's stream decision), `CISOImage::FileIsForm2` (366) -
  meaning kept exactly (rewritten on `SalIsoSectorForm`).
- Content readers reached by every unpack route (whole, selection, F3 / UnpackOneFile) through
  `CISOImage::UnpackFile` -> the file system's `UnpackFile` (366's enumeration, unchanged).

## Analyze

- Run 1: 0 CRITICAL, 0 HIGH. MEDIUM C1 (SC-005 not verified by a task) - fixed (T017). LOW U1 (closing records
  not tasks - the run's closing step), LOW I1 (data-model size formula reads oddly - saltests check both
  identities) - accepted.
- Run 2: 0 CRITICAL, 0 HIGH; the two LOW as above.

## Implementation

- `src/common/salisotrack.h`: `SalIsoSectorForm` (335's subheader checks; valid + Form bit = Form 2, valid without
  = Form 1, anything else unknown) - `SalIsoSectorIsForm2` is now `SalIsoSectorForm == Form 2` (same meaning, 335's
  and 366's tests unchanged and passing); `SalIsoFileNeedsSectorScan` (not 366's Form 2 files, a track that stores
  Form 2 data, length > 0; in a stream track, or the XA Form 2 bit without the directory bit, or a Form 2 first
  sector); `SalIsoSectorScan` + `Init` / `Add` / `Kind` / `Size` (per sector 2324 or 2048, the last non-Form-2
  sector the record's remainder; the leading run of sectors read whole stops at the first unknown sector and at a
  last non-Form-2 sector the record ends inside).
- `isoimage.h/.cpp`: `CFilePos::Form2` 0 / 1 / `FORM2_MIXED` (2), `Scanned`, `WholeSectors`;
  `CISOImage::ExamineFileSectors` (the start track as 366's `FileIsForm2`; one 24-byte read of the first sector,
  then the trigger; an examined file's stored sectors 64 a read; out of memory marks the listing);
  `CISOImage::ReadMixedBlock` (the open track's stored sector head -> `ReadForm2Block` or `ReadBlock(2048)`);
  `NoteListedFileStarts`: a scanned file's span = its `WholeSectors`.
- `iso9660.h/.cpp`: `AddFileDir(..., examine, xaKnown, xaAttrs)` - only `ListDirectoryRe`'s file records pass
  `examine` (folders and the boot record's virtual record do not); 366's branch first, else the examination:
  all Form 2 -> `Form2 = TRUE` and 366's size, mixed -> `FORM2_MIXED` and the scan's size; `UnpackFile` reads a
  mixed file with `ReadMixedBlock` (`nbytes` = what the sector gave, at most the remaining listed size).
- `rawfs.cpp`: `CRawFS::UnpackFile` the same (the stream tracks have no file system: the CloneCD / NRG rows).
- SC-005 (from the code path): a file on a track that stores Form 2 data costs one 24-byte read before the trigger
  decides; only an examined file's sectors are read, 64 stored sectors a read; tracks that cannot hold Form 2 data
  (cooked, Mode 1) return before any read.
- The extracted size equals the listed size by construction: both readers write until the listed size is
  reached (`remain`), each sector giving what the listing counted for it.

## Checks

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `saltests.exe` | 29,984 checks, 0 failed (`TestIsoSectorScan_367`) |
| mutants | `probe/mutants367.ps1` (each rule changed in the header, built, saltests, restored) | form1-as-unknown 3 failed; stream-trigger-dropped 1; xa-trigger-dropped 2; unknown-counts-whole 2; run-never-stops 2; partial-last-whole 3; size-last-full 3; mixed-as-form2 5 - every mutant fails; header restored (diff unchanged), rebuilt, 29,984 / 0 |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| clang-format | VS clang-format `--lines` of the changed lines (session script) | two `if` lines in iso9660.cpp / rawfs.cpp re-wrapped as clang-format wants; the rest unchanged |
| probe after | `probe/iso367_probe.ps1 -ImgDir %TEMP%\tc367img -Label after` (images `probe/img367.py`) | `probe/result_after.txt` **PASS 36, FAIL 0** (18 rows); registry restored + identical |
| negative control | the same probe with main 56a44fba's `uniso.spl` (worktree `%TEMP%\tc367neg`, built into `%TEMP%\tc367negbuildtandemcommander`, copied into a copy of the Debug tree `%TEMP%\tc367negtree`) | `probe/result_negative_main.txt` **PASS 27, FAIL 9**: exactly the nine 367 rows fail (608,256 bytes - the 2048-byte cut; C-LASTF1 607,208; C-BADSUB's image deleted); 366's rows pass on both |
| regressions | `%TEMP%\tc367work\regress.ps1`: 337's, 365's, 334's probes on the feature build | `regress_365.txt` 22 / 0; `regress_334.txt` 23 / 1 (S-RAW - 335's intended change, as recorded since 335); `regress_337.txt` 54 / 20 - see below |
| 337 with 367's expectations | `probe/iso337_r367_probe.ps1` (337's probe and images; content compared with the whole 2324-byte payloads) | `regress_337_r367.txt` **74 / 0**; `-FoldersOff` `regress_337_r367_foldersoff.txt` **8 / 0** |

Probe rows (feature build): C-MIXED, C-NOXA, C-NOXA-NRG - AVSEQ01.DAT 690,228 bytes, `v.mpg` whole in it, the
image deleted (as a real Video CD, every stream extracted whole); C-MIXED-BIN, C-NOXA-BIN - the same content
through the plain detection's ISO 9660 reader (image kept by the plain detection's rest rules, as R-VCD-BIN);
C-F1SUB, C-F1SUB-BIN - AVSEQ02.DAT 689,952 bytes = 2048 + 296 x 2324 (its Form 1 first sector's 2048 bytes, then
the 2324 of each Form 2 sector), deleted / kept as above; C-BADSUB - sector 100's subheader damaged: that sector
2048 bytes (689,952 in all), the image KEPT (the whole run stops at sector 100, 347 sectors uncovered - feature
337 marks); C-LASTF1 - record 296 x 2048 + 1000 ending in a Form 1 sector with data past those 1000 bytes:
688,904 bytes, the image KEPT; 366's rows (R-*, C-COOKED, C-CUT, C-SHORT240, D-DIFF2-*) unchanged.

337's own probe on the feature build (`regress_337.txt`, 54 / 20): its synthetic stream files (`avseq01.dat`, and
`a.txt` pointed into a stream by review 2) have no XA record and start in a Form 2 stream - exactly the files this
item names (335's X-VCDFILE shape) - so they are now read 2324 bytes a sector; 337's probe compares them with the
2048-byte cut ("wrong content" in 20 rows). The image's fate is unchanged in every row but S-VCDBYTE: its file
(63 x 2048 + 1 bytes over 64 Form 2 sectors) is now read whole, 64 x 2324 bytes - the stream has nothing left
unextracted, the image is deleted (337 kept it because the 64th sector was cut). The variant probe with 2324-byte
expectations proves the new content of all 20 rows byte for byte (74 / 0).
