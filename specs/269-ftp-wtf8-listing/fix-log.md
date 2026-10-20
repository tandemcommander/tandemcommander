# Fix log - 269-ftp-wtf8-listing

Backlog item `ftp-wtf8-name-listing-round-trip`: an FTP file name with an unpaired UTF-16 surrogate
comes back garbled from a UTF-8 server; re-upload may overwrite.

## Measurement at HEAD b1feb7ab (before)

- Reading: `FTPListingFieldToU8` (`src/plugins/ftp/ftputils.cpp`) kept a field only when ASCII or
  `MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)` accepted it; that strict call refuses
  `ED A0 80` (U+D800 in WTF-8), so the whole name went to the `CP_ACP` branch and
  `FTPAddCodePageName`. Callers: `AssignStringToColumn` (`parser2.cpp`) for every listing column
  (the panel and `CUploadPathListing::ParseListing` -> `ParseListingToArray`, `operats9.cpp`) and
  `FTPDecodeServerReplyPathInPlace` (PWD). No other decode of names in `src/plugins/ftp` (grep
  `MB_ERR_INVALID_CHARS` / `CP_ACP`). Senders: `FTPU8NameToServer` sends a WTF-8 name verbatim.
- `python tools/check_encoding.py --plugins`: `plugins/ftp/ftputils.cpp:3627
  [strict-probe-rejects-wtf8]` (16 findings of the rule in all).
- Docker is not running on the machine (`docker ps`: no engine pipe) - instead 215's `ftpmini.py`
  with a new ENC `wtf-8` (UTF-8 with Python's `surrogatepass`: lone surrogates byte for byte, as a
  UNIX server; checked: `os.listdir` -> `'a\ud800.txt'`, encode -> `61 ED A0 80 2E 74 78 74`).
- Probe `probe/ftp269_probe.ps1` (run from the scratch folder with a copy of the server carrying
  the same change; the result copied to `probe/result_before.txt`), ACP 1250, Debug x64 at b1feb7ab:
  - DL FAIL - F5 of the server's `a<U+D800>.txt` created local `a<U+00ED><U+00A0><U+20AC>.txt`; the
    Copy dialog showed `aí €.txt`.
  - UP-NEW PASS - the server holds `a<U+D800>.txt` (STOR carried the WTF-8 bytes).
  - UP-ASK FAIL - no "Target File Already Exists", STOR sent, the server's file overwritten
    (content LOCAL instead of SRV). **The overwrite of the item reproduced** - severity 7 stays.
  - DL-ACC, LEG-DL PASS (controls).
- Note: the probe shows the server log's lone surrogate as `�` (`RETR a�.txt`) - the
  log's JSON `\ud800` becomes U+FFFD in `ConvertFrom-Json`; the file names checked on disk carry
  U+D800 (the rows judge the disk).

## Decisions

- Rule `SalFtpListingFieldIsU8` in the new header-only `src/common/salftplisting.h` (the FTP
  plug-in cannot compile a `.cpp` from `src/common`): ASCII or WTF-8, the exact set
  `SplUnicodeDetail::Wtf8ToW` accepts, length-bounded, NUL byte valid (as the strict call with a
  length had it). The call site replaces the ASCII loop + strict call; the code-page branch,
  `FTPAddCodePageName` and the raw fallback are unchanged.
- Limit (spec Edge Cases, research R3): a legacy code-page name whose bytes form a WTF-8 surrogate
  sequence (cp1250 `í` + 0xA0..0xBF + 0x80..0xBF) is now taken for WTF-8 - chosen by the item.
- analyze: C1 (MEDIUM) - the PWD path decode has no probe row; it is the same function and the
  rule is checked in saltests - accepted. U1 (LOW) - the negative control made concrete (T011).

## Implementation

- `src/common/salftplisting.h` (new), `src/plugins/ftp/ftputils.cpp` (include + the condition),
  `src/saltests/saltests.cpp` (`TestFtpListingField269`: 38 checks - 34 named cases, and an exhaustive comparison
  over 168,420 byte strings of 1..4 bytes from a 20-byte alphabet with every byte class: rule ==
  `Wtf8ToW` for all, every string the strict call accepts is accepted).
- `specs/215-ftp-long-name-command/probe/ftpmini.py`: ENC `wtf-8` added (`WIRE, ERRS`); the other
  modes encode / decode exactly as before.
- Probe fix: `$PSScriptRoot` is empty in a PowerShell 5.1 param default - the first after run ended
  at the param block (before the registry backup; nothing touched); `$Repo` now defaults in the
  body.

## After (branch 269-ftp-wtf8-listing)

- `.\build.cmd` -> `BUILD SUCCEEDED` (ftp.spl rebuilt 21:49).
- `saltests.exe` -> `saltests: 24816 checks, 0 failed` (the negative control: the strict
  `MultiByteToWideChar` refuses `a ED A0 80 .txt` - CHECK holds, i.e. the old test was the defect).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`;
  `--plugins` -> `[strict-probe-rejects-wtf8] 15 finding(s)`, no `ftputils.cpp`.
- Probe `probe/result_after.txt`: DL PASS (local `a<U+D800>.txt`, Copy dialog shows the name),
  UP-NEW PASS, UP-ASK PASS ("Target File Already Exists" shown, Skip, no STOR, server content SRV),
  DL-ACC PASS, LEG-DL PASS - 10 / 0 (5 ROW + 5 END rows); registry restored, identical.
- Regression: feature 224's probe -> `probe/regress_224.txt` 16 / 0 (UTF-8 and cp1250 servers,
  the PWD home folder in the code page).
- T006: the upload's existence check needed no change - UP-ASK passes with the decode fix alone.

## Review

### Review 1 (independent, refute-first) - no MUST, 2 SHOULD, 5 NOTE

- Re-ran build, saltests (24816 / 0), the guard, the probe (10 / 0); negative control: main's
  `ftputils.cpp` put back temporarily, only `ftp.spl` rebuilt -> DL and UP-ASK FAIL, controls PASS
  (reverted, rebuilt). Callers enumerated independently: the same two. The rule equals `Wtf8ToW`
  apart from the length bound; a mutation dropping the end-of-field check is caught.
- SHOULD 1 - the limit's upload consequence was not written down: on a cp1250 server a name with
  bytes `78 ED A0 80 .txt` is now listed as `x<U+D800>.txt`; uploading a local file of the
  code-page name no longer asks, STOR in UTF-8 creates a second file (no overwrite). **Done**: spec
  Edge Cases record it (with the closest real cases, cp1251 `нії`, cp932 IBM kanji); the item's
  approach chose WTF-8, so no code change.
- SHOULD 2 - no probe row for a folder / PWD path, none for download over an existing file.
  **Done**: rows DL-ASK and DIR-DL added to `probe/ftp269_probe.ps1` (from the reviewer's extra
  probe) -> `probe/result_after_review1.txt` 14 / 0 (7 ROW + 7 END), registry identical. Old build:
  DIR-DL FAIL (local folder `d<U+00ED><U+00A0><U+20AC>`) - `probe/result_review1_control_main.txt`
  (the reviewer's run; its LEG-AMB rows show the old code page reading of the ambiguous name).
  analyze C1 is now covered by DIR-DL.
- NOTEs (no change): the CESU form does not round-trip on upload (recorded in Edge Cases); a NUL
  byte inside a field cuts the name at the NUL (`str[len] = 0` after `memcpy` - older than this
  feature, the C string cannot carry it); `FTPDecodeServerReplyPathInPlace` copies with
  `lstrcpyn` (older, already the backlog item `ftp-pwd-and-created-path-cut`; this feature only makes WTF-8 paths shorter than the code-page reading did);
  CHANGELOG / FEATURE-HISTORY entries are the closing step; one reviewer LEG-AMB-UP run did nothing
  (probe-driver focus timing, not the product).
