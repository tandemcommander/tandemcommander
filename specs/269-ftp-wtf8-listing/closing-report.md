# Closing report - 269-ftp-wtf8-listing
Backlog item: ftp-wtf8-name-listing-round-trip - FTP: a file name with an unpaired surrogate comes back garbled from a UTF-8 server; re-upload may overwrite
Outcome: closed

## What changed

- `src/common/salftplisting.h` (new, header-only, pure): `SalFtpListingFieldIsU8(s, len)` - TRUE
  for ASCII or WTF-8 (exactly the set `SplUnicodeDetail::Wtf8ToW` / `SplU8ToW` accepts),
  length-bounded, a NUL byte valid.
- `src/plugins/ftp/ftputils.cpp` `FTPListingFieldToU8`: the ASCII loop + strict
  `MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)` keep-test replaced by the rule; the
  code-page branch of feature 224 unchanged. Serves every listing column (panel, upload listings)
  and the PWD path.
- `src/saltests/saltests.cpp`: `TestFtpListingField269` (38 checks, one an exhaustive comparison
  with `Wtf8ToW` over 168,420 byte strings).
- `specs/215-ftp-long-name-command/probe/ftpmini.py`: ENC `wtf-8` (UTF-8 with `surrogatepass`);
  other modes unchanged.
- New probe `specs/269-ftp-wtf8-listing/probe/ftp269_probe.ps1` (7 rows).

## Measurements (before / after, commands)

- Before (b1feb7ab, `probe/result_before.txt`): DL FAIL (local `a<U+00ED><U+00A0><U+20AC>.txt`),
  UP-ASK FAIL (no question, STOR, server file overwritten), UP-NEW / DL-ACC / LEG-DL PASS.
- After (`probe/result_after.txt` 10 / 0; `probe/result_after_review1.txt` 14 / 0 with DL-ASK and
  DIR-DL): every row PASS, registry restored and identical.
- Negative control (review 1): main's `ftputils.cpp` put back -> DL, UP-ASK, DIR-DL FAIL
  (`probe/result_review1_control_main.txt` for DIR-DL).
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\269-ftp-wtf8-listing\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\269-ftp-wtf8-listing\probe\ftp269_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `--plugins`
  `strict-probe-rejects-wtf8` 16 -> 15, `ftputils.cpp` gone.
- `.\build.cmd` -> `BUILD SUCCEEDED`.
- `saltests` -> `saltests: 24816 checks, 0 failed`.
- Probes: ftp269 14 / 0; feature 224's probe (regression) 16 / 0 (`probe/regress_224.txt`).

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD 1 - the limit's upload consequence on a legacy server
  (a second file, no overwrite) recorded in the spec's Edge Cases and the CHANGELOG limitation.
  SHOULD 2 - probe rows DL-ASK and DIR-DL (folder / PWD path) added, 14 / 0. NOTEs recorded in
  `fix-log.md` (CESU form, NUL in a field, PWD `lstrcpyn` - already the backlog item
  `ftp-pwd-and-created-path-cut`).

## Owed to a person

- None. (A real vsftpd / Linux server was not used - Docker was not running; the local server
  stores the bytes the same way.)

## New Inbox items (slug - title)

- None.
