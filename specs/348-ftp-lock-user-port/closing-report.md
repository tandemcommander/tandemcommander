# Closing report - 348-ftp-lock-user-port
Backlog item: ftp-two-uploads-as-another-user-or-port-of-one-server-can - FTP: two uploads as another user or port of one server can store one file at once
Outcome: closed

## What changed

- `src/plugins/ftp/operats9.cpp` `CFTPOpenedFile::IsSameFile`: the opened-file lock no longer
  compares the user and the port (347 already dropped the host). Two accesses to the same server
  path and name are maybe the same file on any connection (feature 345's rule); a conflicting
  second access is refused as before ("Target File Is Locked By Another Operation", retryable).
- `src/plugins/ftp/operats.h`: field and method comments.
- New probe `probe/ftp348_probe.ps1` with `probe/ftpmini_hold2.py` (347's holding test server that
  also listens on a second port: one folder, one log).

## Measurements (before / after, commands)

- Before (`main` 4e2c8835): `ftp348_probe.ps1` on the hidden desktop -> `probe/result_main.txt`
  PASS 7 / FAIL 3: OTHER-USER, OTHER-PORT, ALL-OTHER - 2 STOR hold.txt, 1 while the other was in
  flight, server file 'UP2'.
- After: `probe/result_after.txt` PASS 10 / FAIL 0 - 1 STOR, 0 overlapping, upload 2 refused by the
  lock, server file 'UP1'. Commands in `fix-log.md`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- saltests: not run - no change under `src/common/` or the core.
- Probes: 348 10 / 0; regressions 341 12 / 0, 345 16 / 0, 347 6 / 0 (`probe/regress_*.txt`);
  registry restored + identical in every run.
- No UI text changed: no `.slt` refresh.

## Reviews (findings and what was done)

Review 1 (refute-first): MUST 0, SHOULD 2, NOTE 3. Its negative control (only the old `ftp.spl`
in a copy of the branch tree) fails OTHER-USER, OTHER-PORT, ALL-OTHER. SHOULD 1 - limit: a shared
folder seen at two different absolute paths (per-account chroot, a server symbolic link) is still
two files to the lock (no client rule can see it) - named in the spec, FEATURE-HISTORY and the
changelog text below. SHOULD 2 - closing artifacts - done. NOTE 2: the open item
`ftp-server-path-compare-code-page-fold` (case-insensitive server path compare by the code page)
now applies across all connections (same kind of effect: an extra refusal or a missed non-ASCII
case match); the item is left unchanged for the maintainer. Details in `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (there is no `## [Unreleased]` section in `CHANGELOG.md`; versions
  and sections are the maintainer's):

  - **Two FTP uploads of one file as two users or through two ports of one server no longer
    store it at once** (feature 348). An upload running as another user of a server (two accounts
    that share a folder) or through another port of it (a forwarded port) and an upload of the
    same file into a panel stored the file at the same time, and the first upload's file was
    replaced without a question. Now the second upload's item is refused as "Target File Is
    Locked By Another Operation" until the first one ends (Retry). Cost: while one file is being
    written, a conflicting access to a file with the same server path and name on any other FTP
    connection - also on an unrelated server (`/index.html` uploaded to staging and production at
    once) - is refused and must be retried; two downloads still run together. Limit: a shared
    folder that two accounts see under different absolute paths is still not recognised.

## New Inbox items (slug - title)

- none
