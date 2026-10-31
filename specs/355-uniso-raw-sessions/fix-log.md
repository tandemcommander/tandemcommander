# Fix log - 355-uniso-raw-sessions

Backlog item `iso-plug-in-a-raw-multi-session-image-not-named-img-lists` (review:354) - ISO plug-in: a raw
multi-session image not named .img lists one session, then Unpack deletes it.

## Measurement before (main at 4cc97934)

- Read: `CISOImage::Open` (`src/plugins/uniso/isoimage.cpp`), plain branch: 353's block needs `CcdMissing`
  (only `ReadSessionCCD`, reached from `ReadSessionInfo` for `.img`) and `rawStart`; 354's block needs
  `cookedIso` (`!rawStart`). `ReadSessionInfo` reads a table only for `.nrg` / `.img`; uniso registers
  `*.iso;*.isz;*.nrg;*.bin;*.img;*.pdi;*.cdi;*.cif;*.ncd;*.c2d;*.mdf;*.dmg` (`uniso.cpp`). Caller chain:
  Alt+F9 -> core -> `ListArchive` -> `CISOImage::Open` -> `ListImage`; `UnpackArchive` fails a whole unpack
  only when `pd->ListingLeftOut` (328).
- `.\build.cmd` (Debug x64 at HEAD) -> BUILD SUCCEEDED.
- Probe (new, `probe/iso355_probe.ps1` + `probe/img355.py`, written in a scratch folder before the branch
  existed, same content; seeds by 334's `mkimg334.sh`):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\iso355_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile <scratch>\result_before_rows.txt"`
  -> **30 PASS / 10 FAIL** (`probe/result_before_debug.txt`). FAIL - image deleted, b.txt (or the tail)
  lost: R-TWOISO, R-TWOBIN, R-TWOMDF (the reviewer's seed of 354 under three names), R-XA2BIN, R-BIGPVD,
  R-SHORT, R-REST17, R-ZERO513, R-ZEROLATE, R-AUDIO. PASS: the 8 C rows (deleted), U-TWOIMG and
  U-ZERO150IMG (353: kept, "Missing .CCD file"). Registry restored, identical (SHA-256 1DA45396...).
- *Notes* asked to measure how a real one-session `.bin` / `.mdf` ends first: no `.cue` / `.mdf` / `.mds`
  on the machine (`find` over the user profile, D:, E: to depth 4, nothing). Reasoned instead (research
  R2): a data track's post-gap is stored as sectors of zero user data, a run-out read as zero bytes;
  crafted rows C-ZERO150 / C-RUN2 stand for them. Deviation -> person step at closing.
- `BL verify` recorded.

## Decisions (spec Clarifications)

- Raw start, `CcdMissing` false: `SalIsoRawRestDecision` - MARK unknown size / bad sector size / file
  within the volume / more than 512 sectors past; KEEP at most 16 past; else CHECK the 2048 user-data bytes
  of every whole sector past the volume at the opened layout - mark on a short read or a non-zero byte.
- 353's `.img` rule unchanged (no zero check there - its R-REST17 decided row).
- No valid descriptor at sector 16 (HFS-only raw image): marked (fails closed).

## Analyze

- Run 1: 0 CRITICAL, 0 HIGH, 0 MEDIUM; LOW C1 (C-RUN2 falls under the 16-sector keep, not the zero check -
  C-ZERO150 / C-ZERO512 exercise it) and LOW I1 (T007 runs more regressions than SC-003 names) - accepted.

## Implementation

- `src/common/salisotrack.h`: `SAL_ISO_RAW_REST_READ` (2048) and `SalIsoRawRestDecision` (data-model.md).
- `src/plugins/uniso/isoimage.cpp`: `Open`'s plain branch, after 353's block, a block for
  `rawStart && !CcdMissing`: the descriptor at `GetSectorOffset(16)` (132 bytes), the rule; for CHECK the
  2048 user-data bytes of each sector past the volume at `DataOffset + n * SectorRawSize +
  SectorHeaderSize` (64-bit), a short read or a non-zero byte marks; `ListingLeftOut.SetIncomplete()`.
- `src/saltests/saltests.cpp`: `TestIsoRawRest_355` (39 checks), called after `TestIsoCookedRest_354`.
- Consumers enumerated (Grep `ListingLeftOut`, `CcdMissing`, `rawStart`): `ListingLeftOut` is copied by
  `ListArchive` to `pd->ListingLeftOut`, which whole unpack checks (328); `UnpackOneFile`, `ViewFile`,
  `CanViewFile` open the image again and ignore the mark. `rawStart` / `CcdMissing` are read only in
  `Open`. No UI string, no `.rc` / `.rc2` / `.rh` change -> no translation refresh (stop-rules §2.13 does not
  apply).

## Measurements after

- `.\build.cmd` -> BUILD SUCCEEDED (no warning in the changed files).
- saltests: 29,363 (354's count) -> **29,402 checks, 0 failed**.
- Probe after (`probe/result_after_debug.txt`, log `probe/result_after.txt`): **40 PASS / 0 FAIL** - the 10
  R rows kept (a.txt extracted, no window), the 8 C rows deleted, U-TWOIMG / U-ZERO150IMG unchanged.
  Registry restored identical (SHA-256 1DA45396...).
- Mutant (a) - the rule returns KEEP_LISTING first: saltests 29,402 / **26 failed**; probe **30 / 10**, the
  10 R rows deleted (`probe/result_mutant_never_marks.txt`).
- Mutant (b) - the zero check never passes (every CHECK marks): probe **38 / 2**, C-ZERO150 and C-ZERO512
  kept (`probe/result_mutant_never_zero.txt`) - the post-gap rows depend on the check.
- Both mutants reverted (`git diff | grep MUTANT` empty), rebuilt, saltests 29,402 / 0.
- Regressions on the fixed build (`probe/regress_<n>.txt`): 354 28 / 0, 353 16 / 0, 352 22 / 0, 334 23 / 1
  (S-RAW, failing since 335 as 354 recorded - unchanged).
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s); clang-format `--dry-run` on the changed
  line ranges: no change.

## Deviation and limits

- *Notes* asked for a real `.bin` / `.mdf` tail first: none on the machine -> reasoned (research R2) and
  crafted (C-ZERO150, C-RUN2); person step at closing to try real dumps.
- Limits: a raw image whose sector 16 is not an ISO 9660 primary descriptor (HFS-only, UDF-only raw) is now
  kept without a message (fails closed); a raw one-session dump with a non-zero tail of more than 16
  sectors (e.g. a data + audio `.bin` without its `.cue`) is kept - intended, the audio is never extracted;
  353's `.img` rule still keeps zero tails (unchanged by decision); the sessions are still not read (only
  the first is listed); a kept image gets no explanation.
