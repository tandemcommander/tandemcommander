# Fix log - 354-uniso-cooked-sessions

Backlog item `iso-plug-in-a-cooked-multi-session-image-lists-one-session` (review:353).

## Measurement before (main at 64e207ca, Debug build)

- Probe `probe/iso354_probe.ps1` (new; seeds by 334's `mkimg334.sh`, cooked images by `probe/img354.py`,
  xorriso images by `probe/mkxorriso354.sh`), on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\iso354_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"`
  -> **20 PASS / 8 FAIL** (`probe/result_before_debug.txt`). FAIL: R-TWOISO, R-TWOIMG (the defect: s1 + s2
  joined, a.txt extracted, the image deleted, b.txt lost), R-REST17, R-ZERO513, R-ZEROLATE, R-SHORT,
  R-BIGPVD, R-XESP (all deleted). PASS: C-PLAIN, C-REST16, C-ZERO168, C-ZERO512, C-XDEV1, C-XMS (deleted,
  as wanted). Registry restored, identical hash.
- The item's *Notes* measurement - how many sectors past the ISO 9660 volume real tools leave
  (`probe/measure_tails.sh`, `probe/measure2.sh` in WSL Ubuntu; genisoimage 1.1.11 from 334's
  `~/tc-genisoimage`, xorriso 1.5.6 fetched without root into `~/tc-xorriso` by `apt-get download`):

  | Image | file sectors | volume | rest | rest content |
  |---|---|---|---|---|
  | genisoimage `-udf` | 1298 | 1298 | 0 | - |
  | genisoimage El Torito | 1053 | 1053 | 0 | - |
  | genisoimage default / `-pad` | = | = | 0 | - (padding counted in the volume) |
  | xorriso `-as mkisofs` default | 1051 | 1051 | 0 | - |
  | xorriso `-no-pad` | 901 | 901 | 0 | - |
  | xorriso `--protective-msdos-label -partition_offset 16` | 1067 | 1067 | 0 | - |
  | xorriso `-isohybrid-gpt-basdat` | 1052 | 1052 | 0 | - |
  | xorriso `-append_partition 2 0xef` (2880 KiB) | 2491 | 901 | 1590 | the partition (not listed) |
  | the same as GPT | 2507 | 901 | 1606 | the partition |
  | xorriso native `-dev`, one session | 224 | 56 | 168 | zero bytes (last non-zero sector 55) |
  | xorriso native, two sessions | 256 | 88 | 168 | zero bytes; PVDs at 16 (88 = newest), 48, 80 |
  | s1 + s2 joined (the defect) | 352 | 176 | 176 | session 2 (PVD at 192) |

  No real `.iso` file exists on this machine (searched C:\Users\pavel, D:\-G:\ to depth 5).
- Hence the rule (spec *Clarifications*): a zero-only rest (read in full, at most 512 sectors) is not
  marked; any non-zero byte more than 16 sectors past the volume, a longer rest, an unreadable size, a
  file shorter than its volume, or a failed read marks the listing.

## Analyze

No CRITICAL / HIGH. Accepted: U1 (a failed `GetFileSize` gives a size far past the cap -> marked), L1 (the
cap counts bytes; a partial sector past 512 whole ones marks - fails closed).

## Implementation

- `src/common/salisotrack.h`: `SAL_ISO_ZERO_REST_SECTORS` (512), `SAL_ISO_COOKED_SECTOR` (2048),
  `SAL_ISO_REST_KEEP_LISTING` / `_MARK` / `_CHECK`, `SalIsoCookedRestDecision` (no ISO 9660 descriptor ->
  keep; size unknown, negative file size, fewer whole sectors than the volume -> mark; at most 16 whole
  sectors past -> keep; more than 512 sectors of bytes past the volume -> mark; else check the bytes from
  the volume's end to the end of the file), `SalIsoBytesAllZero`.
- `src/plugins/uniso/isoimage.cpp`, `CISOImage::Open` plain branch: `cookedIso` set when `CheckForISO`
  succeeds with `rawStart` false and the stISO layout (offset 0, 2048, no header); after `DetectTrackFS`
  (and after 353's raw block) the descriptor at sector 16 is read (132 bytes), `iso9660` =
  `IsValidCDHeader`, the decision taken with `track->End`; CHECK reads the rest in 64 KiB pieces (heap
  buffer; allocation failure or a short read marks); a mark is `ListingLeftOut.SetIncomplete()` with a
  TRACE_I line. The image is opened for every listing; the extra read is at most 1 MiB and only for a
  rest of 17..512 sectors.
- `src/saltests/saltests.cpp`: `TestIsoCookedRest_354` (38 checks), called after `TestIsoNoCcdRest_353`.
- clang-format of VS 2022 on the changed lines only (`--lines`): two test lines reformatted by hand.

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests` 29,325 -> **29,363 checks, 0 failed**.
- Mutant 1 (`SalIsoCookedRestDecision` always KEEP_LISTING): saltests 19 failed; probe
  `probe/result_mutant_never_marks.txt` **20 / 8** - the 8 R rows fail, as before the fix.
- Mutant 2 (`SalIsoBytesAllZero` always false): probe `probe/result_mutant_never_zero.txt` **24 / 4** -
  C-ZERO168, C-ZERO512, C-XDEV1, C-XMS kept (so the zero rows really exercise the read).
- After: `probe/result_after_debug.txt` **28 / 0** (14 RUN rows). R-TWOISO / R-TWOIMG keep the image
  (only the "Missing .CCD file" boxes for the `.img`, no window for the `.iso`).
- Regressions (`probe/regress_<n>.txt`, the fixed build): 353 16 / 0, 352 22 / 0, 334 23 / 1 (S-RAW kept -
  its state since feature 335, recorded there as the intended change), 328 20 / 0, 329 14 / 0,
  330 30 / 0, 332 16 / 0, 333 20 / 0, 338 24 / 0, 339 20 / 0, 349 10 / 0. Registry restored and identical
  after every run.

## Limits / leftovers

- A UDF-only cooked image (no ISO 9660 descriptor at sector 16) is unchanged - Inbox
  `iso-plug-in-a-udf-only-cooked-image-with-more-past-its` (leftover:354).
- Images with an appended partition past the ISO 9660 volume (Ubuntu installation ISOs since 20.10, by the
  xorriso measurement; no real image tried) are now kept after a whole unpack with "Delete archive after
  unpacking" - their partition is not listed. No new message (as 334 / 353).
- The sessions themselves are still not read (only the volume at sector 16 is listed).
