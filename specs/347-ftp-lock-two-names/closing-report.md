# Closing report - 347-ftp-lock-two-names
Backlog item: ftp-opened-file-lock-two-names-of-one-server - FTP: two operations under two names of one server can open one file at the same time
Outcome: closed

## What changed

- `src/plugins/ftp/operats9.cpp` `CFTPOpenedFile::IsSameFile`: the host is no longer compared. The
  same user, port, server path and file name under any host name are maybe the same file
  (feature 341's "maybe the same server" rule). The conflict table and every caller's refusal are
  unchanged.
- `src/plugins/ftp/operats.h`: comments of `IsSameFile` and the `Host` field.
- New probe `probe/ftp347_probe.ps1` + server `probe/ftpmini_hold.py` (323's `ftpmini_hide.py`
  holding a `hold*` STOR 20 s before the file is created; logs `stor-begin` / `stor-done`).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\347-ftp-lock-two-names\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\347-ftp-lock-two-names\probe\ftp347_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

- `main` 794b3207 (`result_main.txt`): PASS 5 / FAIL 1 - ALIAS-LOCK: 2 STOR hold.txt, 1 while the
  other was in flight, server 'UP2', both operations "(100 %)".
- Branch (`result_after.txt`, `result_after_review.txt` with the tightened verdict): PASS 6 /
  FAIL 0 - ALIAS-LOCK: 1 STOR, upload 2 listed and was refused "Target File Is Locked By Another
  Operation", server 'UP1'.
- Reviewer's negative control: the parent commit's `ftp.spl` alone in a copy of the branch tree ->
  ALIAS-LOCK FAIL.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (pre-existing C4267 warnings of the FTP plug-in only).
- saltests: not run - nothing under `src/common/` or the core changed.
- Probes: 347 6 / 0; 341's `ftp341_probe.ps1` 12 / 0 (`probe/regress_341.txt`); 345's
  `ftp345_probe.ps1` 16 / 0 (`probe/regress_345.txt`); registry restored with identical hash each
  time.
- No UI text, resource, stored data or network change: no `.slt` refresh, no `PRIVACY.md` change.

## Reviews (findings and what was done)

One refute-first review: MUST 0. SHOULD 1 (ALIAS-LOCK verdict could pass without upload 2
running) - fixed, re-run 6 / 0. SHOULD 2 (name the cost) - in FEATURE-HISTORY and the changelog
text below. NOTE 1 (SAME-LOCK does not reach the lock) - documented in the probe; NOTE 2 (user /
port) - Inbox item; NOTE 3 (existence check before the lock, by reading) - Inbox item.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (there is no `## [Unreleased]` section in `CHANGELOG.md`; versions
  are the maintainer's):

  - **Two FTP uploads of one file to one server under two of its names stored it at the same
    time** (feature 347) - an upload to `localhost` and one to `127.0.0.1` (a server's name and
    its address, same user and port) both stored the file and the first upload's file was replaced
    without a question. Now the second one stops with "Target File Is Locked By Another Operation"
    and can be retried when the first one ends. Two different servers with the same user, port,
    folder and file name now also refuse each other's conflicting access while one of them runs.
    Another user or port of one server is still told apart.

No person-step item: everything was driven on the hidden desktop.

## New Inbox items (slug - title)

- `ftp-two-uploads-as-another-user-or-port-of-one-server-can` - FTP: two uploads as another user or
  port of one server can store one file at once (measure:347)
- `ftp-an-upload-that-ends-between-another-upload-s-existence` - FTP: an upload that ends between
  another upload's existence check and its lock (review:347)
