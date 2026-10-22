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
