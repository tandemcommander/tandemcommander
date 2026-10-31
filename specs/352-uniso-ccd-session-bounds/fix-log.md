# Fix log - 352-uniso-ccd-session-bounds

Backlog item `iso-plug-in-a-clonecd-session-number-from-the-ccd-writes` (source review:351).

## Measurement before (main 2f260c23, Debug)

- `.\build.cmd` (incremental, up to date at HEAD) -> BUILD SUCCEEDED.
- New probe `probe/iso352_probe.ps1` (built on 351's; images `probe/img352.py` from 334's
  `mkimg334.sh` seeds; whole Unpack Alt+F9 with "Delete archive after unpacking"), on the hidden
  desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\iso352_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before-main-2f260c23-debug"
  ```

  Result `probe/result_before_debug.txt`: **8 PASS / 10 FAIL** (9 cases x END + RUN):
  - C-M1, C-M1M1 (controls): PASS - extracted, image deleted.
  - R-S0: CRT "HEAP CORRUPTION DETECTED: before Normal block ... Memory allocated at
    ...\src\plugins\uniso\img.cpp(438)" (`pointMin[-1]`).
  - R-S200: no window, a.txt extracted, **the image deleted** after the silent overrun.
  - R-S257: RTC #1 "a cast to a smaller data type has caused a loss of data" (`CCDEntry(BYTE session)`;
    in Release 257 -> session 1).
  - R-ABS (two `[Session n]`, one split): TRACE_C "Index is out of range (index = 1, Count = 1)"
    (`Session[1]` in the sector-format loop; in Release a read past the split list).
  - R-SPLIT (one section, two splits): PASS visibly (Session 01/a.txt, image kept), but `extents[1]` /
    `extentsEnd[1]` read past a one-element array (Debug no-man's-land 0xFDFDFDFD - session 2 does not
    open, which is why the image was kept). The probe cannot tell this read; the rule tests do.
  - R-MODEX (`MODE=x`): "Unknown file format" box, image kept (mode = stack 0xCCCCCCCC -> unknown).
  - R-DUP (entry without PLBA, `Session=` twice): RTC #3 "The variable 'plba' is being used without
    being initialized".
  - Registry restored, identical (SHA-256 1DA45396...).

## Decisions (research.md)

- R1 a refused `.ccd` keeps the box and the plain-detection fallback, and marks the listing incomplete
  (the image is kept by a whole unpack); a missing `.ccd` is not marked.
- R2 sections / splits that disagree: opened within bounds, marked incomplete, no box.
- R3 rows parse as `sscanf` read a valid value (header-only parser, 32-bit range), each needed row once.
- R4 entry session in 1..sections as `int`, all entries checked before any table is built.
- Analyze round 1: MEDIUM E1 (FR-006 untested) -> probe row C-NOCCD added; round 2: clean.

## What changed

- `src/common/salisotrack.h`: `SalIsoCcdReadInt` (a row's value as `sscanf` read a valid one; no
  number or outside 32 bits fails, `out` untouched), `CSalIsoCcdFields` (each needed row once and
  parsed), `SalIsoCcdSessionIndex` (1..sections, else -1), `SalIsoCcdSplitSection`,
  `SalIsoCcdLayoutTrusted`.
- `src/plugins/uniso/img.cpp`: the three section parsers use them (a row with no name, `=...`, is
  skipped instead of `strcmp(NULL)`; `[Disc]` / `[CloneCD]` rows too); `CCDEntry::Session` is `int`;
  `CCD::Refused` set where `IDS_CCD_BAD_FORMAT` is reported; `ReadSessionCCD` checks every entry's
  session before building anything (refused otherwise), runs the sector-format loop over the splits
  (it went over the sections and read `Session[i]` past the split list - the unused `ccdSession` /
  `fileSystemType` locals removed), takes a split's offsets only from an existing section row (else
  0), marks `ListingLeftOut` incomplete when sections and splits disagree and when the `.ccd` was
  refused (a missing `.ccd` is not).
- `src/saltests/saltests.cpp`: `TestIsoCcdBounds_352` (60 checks).
- Probe `probe/iso352_probe.ps1` + `probe/img352.py` (row C-NOCCD added after analyze).

## Implementation notes

- A Bash here-document collapsed `\n` of `"$s\noccd.img"` into a newline in the probe (the 123 / 334
  trap) - fixed with the editor; a control-byte scan of every edited file found 0. The edit scripts
  for `img.cpp` were then written with the editor (`%TEMP%\tc352work\edit_img2.py`).
- First "after" run (`probe/result_after_debug_run1.txt`): 19 / 1 - only C-NOCCD, whose condition
  required exactly one window; the existing "Missing .CCD file" box shows once per open of the image
  (twice in a whole unpack, as the bad-format box in the R- rows). The probe was wrong: the condition
  is now "every window is the missing-.ccd box". The product did as before (a.txt extracted, image
  deleted).

## Measurements after (Debug, the fix)

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 29,226 (351) -> **29,286 checks, 0 failed** |
| rule mutant | `SalIsoCcdSessionIndex` without `session > sections` | 4 failed (2,1 / 200,1 / 257,1 / 0x7FFFFFFF,5); restored |
| probe 352 | `iso352_probe.ps1` on the hidden desktop | main 8 / 10 -> **20 / 0** (`probe/result_after_debug.txt`) |
| regression 351 | `iso351_probe.ps1` | 10 / 0 (`probe/regress_351.txt`) |
| regression 334 | `iso334_probe.ps1` | 23 / 1 - S-RAW, as recorded since 335 / by 351 (`probe/regress_334.txt`) |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| format | clang-format (VS 2022) on the changed lines only | two alignment fixes applied |

Probe rows after: R-S0 / R-S200 / R-S257 / R-MODEX / R-DUP - the bad-format box (twice: listing and
unpack open the image), plain detection lists a.txt, the image **kept**; R-ABS - no box, b.txt (the
last data track, as the single-session listing does), kept; R-SPLIT - no box, a "Read error: Cannot
read sector #00000019" for the split without a section (offset 0; Skip), kept; C-NOCCD - the
missing-.ccd box, a.txt, the image deleted (as before); controls unchanged. No CRT / RTC / TRACE_C
window, no bug report, registry identical.

FR-006 "as before" for C-NOCCD is by reading (a missing `.ccd` returns from `processCCDFile` before
`Refused` can be set) plus the after measurement; the before run predates the row.
