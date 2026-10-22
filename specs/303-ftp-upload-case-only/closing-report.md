# Closing report - 303-ftp-upload-case-only
Backlog item: ftp-an-upload-to-a-case-insensitive-server-with-unix-paths - FTP: an upload to a case-insensitive server with Unix paths replaces b.txt by B.txt without the question
Outcome: closed

## What changed

- New header-only rule `src/common/salftpupname.h`: `SalFtpFindCaseOnlyName` - a listed name that
  is not byte-equal to the target but the same name under feature 092's rule (`SalNameOrderEqualCI`).
- `src/plugins/ftp/operats.h`, `operats9.cpp`: `GetListing(..., caseOnlyCounts)`; with TRUE and no
  exact match, a listed file or link found by the rule counts as existing (folders skipped); the
  copy's size is `UPLOADSIZE_UNKNOWN`.
- `operatsb.cpp`: the file upload's start check, the resume size lookup and the file auto-rename
  pass TRUE; `operatsa.cpp`: the two folder-upload calls pass FALSE (unchanged behaviour).
- `src/saltests/saltests.cpp`: `TestFtpCaseOnlyName303` (18 checks).
- No UI string, setting, stored data, network command or plug-in interface changed.

## Measurements (before / after, commands)

Probe (hidden desktop, PowerShell, repository root):

    powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\303-ftp-upload-case-only\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\303-ftp-upload-case-only\probe\ftp303_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"

- Before (build of 17febaaf, `result_before.txt`): PASS 5, FAIL 3 - `STOR B.txt` without a
  question, the server's `b.txt` replaced (CASE-UP, CASE-OVR); `STOR čaj.txt` over `Čaj.txt`
  (CASE-CZ); the control CASE-NEW passed.
- After the fix (`result_after.txt`): PASS 8, FAIL 0.
- After review 1 (`result_review1.txt`, rows CS-DIR / CS-FILE added on a case-sensitive server
  folder): PASS 12, FAIL 0; the reviewer's negative control (the start check set back to FALSE):
  PASS 5 / FAIL 3; CS-DIR on the pre-review build: FAIL.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (no new warning).
- saltests -> `saltests: 26577 checks, 0 failed`; negative controls: no case-only match 7 failed,
  an ASCII-only fold 2 failed.
- Probes: `ftp303_probe` 12 / 0; regressions 288's probe 20 / 0 (`regress_288.txt`), 224's probe
  16 / 0 (`regress_224.txt`); registry restored and identical in every run.

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD 1 (a case-only folder twin blocked a file upload on a
case-sensitive server) - fixed: folders do not count, two probe rows added. NOTEs 2-6 recorded in
`fix-log.md` *Review* (configured automatic answers on case-sensitive servers - stated as the
changelog's limitation; the "transferred whole?" test with only a twin listed fails instead of
retrying; auto-rename and resume proven by reading; the linear pass's cost; resume on a
case-insensitive server continues the server's file - the user's choice).

## Owed to a person (with the new person-step items)

- `ftp-303-on-real-servers-an-upload-of-b-txt-beside-b-txt-asks` - a real Windows-backed server
  with Unix listings (FileZilla Server), the configured auto-rename / resume answers, a real Unix
  server with a case twin and a `BUILD` file beside a `build` folder.

## New Inbox items (slug - title)

- ftp-303-on-real-servers-an-upload-of-b-txt-beside-b-txt-asks - FTP 303 on real servers: an
  upload of B.txt beside b.txt asks first
