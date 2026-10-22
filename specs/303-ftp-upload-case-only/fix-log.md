# Fix log - 303-ftp-upload-case-only

Backlog item `ftp-an-upload-to-a-case-insensitive-server-with-unix-paths` - FTP: an upload to a
case-insensitive server with Unix paths replaces b.txt by B.txt without the question. Run started
from `main` at 17febaaf.

## Measurement at HEAD (17febaaf)

### By reading

- `src/plugins/ftp/operats9.cpp` `CUploadPathListing::FindItem`: binary search over the listing
  sorted by `SortItems`; `strcmp` when `FTPIsCaseSensitive(PathType)` (`ftputils.cpp`: only
  `ftpsptUnix`), `StrICmp` (code-page fold on UTF-8 bytes) otherwise.
- `CUploadListingsOnServer::GetListing` (same file) answers the upload's name question with
  `FindItem` only: for a Unix path `B.txt` does not find `b.txt`.
- Callers of `UploadListingCache.GetListing` (Grep, all five):
  - `operatsb.cpp` `fwssWorkStartWork` (file upload): `existingItem == NULL` -> `fwssWorkUploadNewFile`
    -> `STOR` without a question - **the defect**.
  - `operatsb.cpp` `fwssWorkUploadGetFileSizeFromListing`: the resume offset / the "transferred
    whole?" test take `existingItem->ByteSize` when `SIZE` fails or is not supported.
  - `operatsb.cpp` `fwssWorkUploadGenNewName`: auto-rename, `nameExists` decides a new name is free.
  - `operatsa.cpp` `fwssWorkStartWork` (folder upload: create / join) and
    `fwssWorkUploadAutorenDirSendMKD` (folder auto-rename) - out of the item's scope (the item:
    "only for the overwrite decision, not for path identity"); a folder `MKD` of a case-only
    twin on a case-insensitive server fails with the server's error, no data is replaced.
- Default configuration: "file already exists" = ask (the 302 probe's REN-UP row saw the
  question with the default settings).

### Probe (hidden desktop, before)

`probe/ftp303_probe.ps1` - 215's `ftpmini.py` (utf-8, 127.0.0.1:2132) on NTFS = a
case-insensitive server with Unix listings; F5 of one local file into the server panel's folder.
Run from the session scratchpad on the build of 17febaaf (`.\build.cmd` -> BUILD SUCCEEDED; the
build folder had held 302's branch build before, rebuilt from `main` first):

    powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\303-ftp-upload-case-only\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\303-ftp-upload-case-only\probe\ftp303_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"

Result `probe/result_before.txt`: PASS 5, FAIL 3 (exit 3); registry restored, identical.
- CASE-UP ROW FAIL - **data loss**: server `b.txt` = `SRV-B`; upload of the local `B.txt`: no
  question, commands `PORT / STOR B.txt / NOOP / CWD /CASE-UP / PWD / PORT / TYPE A / LIST` - the
  `STOR` came before any `LIST` (the cache was seeded from the panel's listing); the server's
  file now holds `LOCAL-B`.
- CASE-CZ ROW FAIL: the same for server `Čaj.txt`, upload of `čaj.txt` (`STOR čaj.txt`, server
  file `LOCAL-C`).
- CASE-OVR ROW FAIL: no question to answer (the file was replaced as in CASE-UP).
- CASE-NEW ROW PASS (control): `c.txt` beside `b.txt` - `STOR c.txt`, no question, `b.txt` kept.
- END rows PASS (exit 0, no reports).

## Decisions

See `spec.md` *Clarifications*: the file system's name rule of 092 (`SalNameOrderEqualCI`),
every server path type, only the file upload's existence check and the file auto-rename's check,
a case-only item's size is unknown (never a resume offset).

## Implementation

- `src/common/salftpupname.h` (new, header-only): `SalFtpFindCaseOnlyName(count, getName, name)` -
  the lowest index of a listed name that is not byte-equal to `name` but the same name under
  `SalNameOrderEqualCI` (092's rule); -1 otherwise; one pass.
- `src/plugins/ftp/operats.h` / `operats9.cpp`: both `GetListing` functions take
  `BOOL caseOnlyCounts`; with TRUE, when `FindItem` (exact by the path type's rule, unchanged and
  tried first) misses, the case-only lookup runs over `listing->ListingItem`; a hit sets
  `nameExists` and returns a copy with `ByteSize = UPLOADSIZE_UNKNOWN`.
- Callers (all five, compiler-checked by the new parameter): `operatsb.cpp` `fwssWorkStartWork`
  (file), `fwssWorkUploadGetFileSizeFromListing`, `fwssWorkUploadGenNewName` pass TRUE;
  `operatsa.cpp` `fwssWorkStartWork` (folder) and `fwssWorkUploadAutorenDirSendMKD` pass FALSE
  (folders and path identity unchanged, spec FR-006).

### By reading (T008, T009)

- Exact first: `FindItem` runs first exactly as before; the case-only pass only after it missed
  (a listing with both `b.txt` and `B.txt` answers `B.txt` exactly).
- A configured automatic answer: the case-only file item has `ItemType == ulitFile`, so the start
  check goes to `fwssWorkUploadFileExists`, whose `GetUploadFileAlreadyExists()` switch (ask /
  auto-rename / resume / resume-or-overwrite / overwrite / skip) applies unchanged; a case-only
  link is resolved by `CWD` of `TgtPath/TgtName` as for an exact link. (A case-only folder first
  went to "cannot create file" - changed after the review, below: folders do not count.)
- Resume: `SIZE <TgtName>` is asked first (a case-insensitive server answers with its file's size -
  resume continues that file, what the user chose); when `SIZE` fails or is not supported, the
  listing copy's size is `UPLOADSIZE_UNKNOWN` -> Resume fails with `ITEMPR_UPLOADUNABLETORESUMEUNKSIZ`,
  Resume or Overwrite overwrites, the "transferred whole?" test fails with
  `ITEMPR_UPLOADTESTIFFINISHEDNOTSUP` - never an append at another name's offset. (With an
  exact-only size lookup instead, the "target no longer exists" branch would put the item back to
  waiting and the start check would find the twin again - a loop; R3 of research.md.)
- Auto-rename: a generated name with a case-only twin in the listing is taken as used; another
  name is generated.
- No string added or removed (FR-007): only code and comments changed; `build.cmd` (not `full`)
  is enough.

## Measurements after

Commands from the repository root (PowerShell unless noted):

- Bash `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`, exit 0.
- `.\build.cmd` -> `BUILD SUCCEEDED` (`ftp.spl` 09:21; warnings only the old C4267 of `fs2.cpp` /
  `parser2.cpp`).
- `saltests.exe` -> `saltests: 26577 checks, 0 failed` (`TestFtpCaseOnlyName303`, 18 checks).
  Negative controls (the header changed temporarily, restored after):
  - no case-only match at all (the old behaviour): `7 failed` (every twin row).
  - an ASCII-only fold (`_stricmp`): `2 failed` (the C-caron and E-acute rows) - the file system
    rule is what the checks require.
- Probe `probe/result_after.txt`: PASS 8, FAIL 0 (before: PASS 5, FAIL 3):
  - CASE-UP: the "Target File Already Exists" question for `B.txt`, no command sent to the server
    after the copy dialog (the decision came from the panel-seeded listing), `b.txt` keeps `SRV-B`.
  - CASE-CZ: the question for `čaj.txt`, `Čaj.txt` keeps `SRV-C`.
  - CASE-NEW: `STOR c.txt`, no question, `b.txt` kept (unchanged).
  - CASE-OVR: question answered Overwrite -> `STOR B.txt`, the server's file holds `LOCAL-B`.
  - END rows: exit 0, no reports (the expected "unfinished FTP operations" exit question after
    the open question rows); registry restored and identical (SHA-256 D8DA635D...).
  - First "after" attempt failed to start: `$PSScriptRoot` is empty in a PowerShell 5.1
    parameter default (`-Repo`); the default is computed after the parameters now. Nothing ran
    before the error (no registry backup taken, no program started).
- Regressions: `probe/regress_288.txt` (288's probe) PASS 20, FAIL 0; `probe/regress_224.txt`
  (224's probe) PASS 16, FAIL 0 - both as recorded by their features.

## Review

### Review 1 (refute-first, independent agent) - MUST 0, SHOULD 1, NOTEs 5

Re-ran on the branch build: saltests 26,577 / 0, encoding guard 0, `ftp303_probe.ps1` 8 / 0.
Its own probe negative control: only the start check (`operatsb.cpp` `fwssWorkStartWork`) set back
to FALSE -> PASS 5 / FAIL 3, `STOR B.txt` / `STOR čaj.txt`, files replaced - the same as
`result_before.txt`; the call is what fixes it and the probe detects it. Callers enumerated - the
five, as recorded. No data-loss path found (a case-only match only adds a question or a refusal,
the size is unknown, no path cut, names compared as UTF-8 by 092's rule).

- **SHOULD 1 (fixed)** - a case-only *folder* blocked a file upload on a case-sensitive server: the
  reviewer made the probe's server folder case-sensitive (`fsutil file setCaseSensitiveInfo <dir>
  enable` - a real Unix server); folder `b.txt`, upload of the file `B.txt`: branch "Error Creating
  Target File ... name is already used for directory", no `STOR`, `B.txt` not created (its dialog
  has Retry / Skip / autorename, no "create anyway"; Retry meets the same lookup); old code:
  `STOR B.txt`, the file created beside the folder. On a case-insensitive server the old code did
  no harm there (the server refuses `STOR` onto a folder). Fix: the case-only pass skips listed
  folders (`operats9.cpp`, the lambda gives NULL for `ulitDirectory`); spec FR-002 / edge case /
  clarification, contract, data model, research R3b updated. Rows CS-DIR and CS-FILE (from the
  reviewer's `probe_cs2.ps1`) added to `ftp303_probe.ps1`. The reviewer's CS-DIR on the pre-fix
  branch build: FAIL (its log `cs_branch.txt`) - the negative control of the new row.
- NOTE 2 (accepted, stated in the changelog's limits) - with a configured automatic answer a
  case-only twin on a case-sensitive server is treated as existing: "skip" skips a free `B.txt`,
  auto-rename uploads it under a new name, resume fails (`SIZE` 550 -> size unknown). The spec's
  trade-off (a question / answer too many rather than a silent replace).
- NOTE 3 (accepted) - the "transferred whole?" test after a dropped connection, `SIZE` not
  supported and only a case-only twin listed: the item now fails with
  `ITEMPR_UPLOADTESTIFFINISHEDNOTSUP` instead of being retried as a new upload; no data loss.
- NOTE 4 (recorded) - auto-rename (FR-003) and the unknown resume size (FR-004) are proven by
  reading and the pure checks only; Resume is not a button of the "Target File Already Exists"
  dialog (buttons: Retry, Overwrite, Overwrite All, Skip), it is reachable only by configuration,
  which the probe does not set.
- NOTE 5 (accepted) - the case-only pass scans the folder listing under the cache lock per new
  name; cheap for ASCII names, quadratic only for a large upload into a large folder (research R4).
- NOTE 6 (no change) - Resume on a case-insensitive server continues the server's `b.txt` at the
  size `SIZE` reports - the user's choice, as for an exact match.

Checks after the fix: `.\build.cmd` -> BUILD SUCCEEDED; saltests 26,577 / 0; encoding guard
`TOTAL: 0 finding(s)`; `probe/result_review1.txt` PASS 12, FAIL 0 (CASE-UP, CASE-CZ, CASE-NEW,
CASE-OVR, CS-DIR: `STOR B.txt`, the file beside the folder; CS-FILE: the question, Overwrite ->
`B.txt` = LOCAL-B beside `b.txt` = SRV-B), registry restored and identical. Only SHOULD findings ->
no second review required (step 7); the SHOULD was inside the item's scope and is fixed.
