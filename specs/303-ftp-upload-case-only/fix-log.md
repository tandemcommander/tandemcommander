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
  folder goes to "cannot create file" (`fwssWorkUploadCantCreateFileDirEx`), a link is resolved by
  `CWD` of `TgtPath/TgtName` as for an exact link.
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
