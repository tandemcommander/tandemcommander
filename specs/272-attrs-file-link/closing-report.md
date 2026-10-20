# Closing report - 272-attrs-file-link
Backlog item: change-attributes-on-a-file-symbolic-link-compresses-re - Change Attributes on a file symbolic link compresses / re-times the target file
Outcome: closed

## What changed

- `src/common/salreparse.h`: the feature 253 decision widened - `SalAttrsEntryIsLink` (any entry
  listed with the reparse bit that the fail-closed link rule takes for a link; replaces
  `SalAttrsEntryIsDirLink`), `SalAttrsOpenFlags(isDir, isLink)` (a file link gets
  `FILE_FLAG_OPEN_REPARSE_POINT`; before 0), `SalAttrsLinkRefusesEncryption(isLink, ...)`.
- `src/worker.cpp` `DoChangeAttrs`: `isLink` for files too (`DeleteAsDirLink`, asked only when
  compression, encryption or times change); compression, times and the encryption refusal use it.
  Copy / Move callers unchanged.
- `src/saltests/saltests.cpp`: `TestAttrsLink253` adjusted (two checks pinned the old "file link
  unchanged"), new `TestAttrsFileLink272` (21 checks).
- `CHANGELOG.md`: entry under 0.1.11 — unreleased; 253's limitation sentence updated.
- Probe `probe/attrs_flink272_probe.ps1` (rows COMP, UNCOMP, TIME, SUBC, PLAIN, NONLINK, ENC).

## Measurements (before / after, commands)

- Outside the program (PowerShell P/Invoke): compression through the worker's flags reached the
  target file, through `FILE_FLAG_OPEN_REPARSE_POINT` the link; times likewise; `SetFileAttributesW`
  already stays on the link; a third-party tag file (0x123) fails the old open with 1920.
- Product, hidden desktop, `run_on_hidden_desktop.ps1` + `attrs_flink272_probe.ps1`:
  before (8b08f1da) `probe/result_before.txt` FAIL 4 (COMP, UNCOMP, TIME, SUBC: the target file
  changed) + `result_before_nonlink.txt` NONLINK PASS; after `probe/result_after.txt` PASS 12 /
  FAIL 0 / NOT DRIVEN 1 (ENC).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (pre-existing C4018 warnings in `salamdr2.cpp`).
- `saltests.exe` -> `saltests: 24835 checks, 0 failed`.
- Probes: 272 12 / 0 / 1 NOT DRIVEN; 253's `probe/regress_253.txt` 10 / 0 / 1; 213's
  `probe/regress_213.txt` 8 / 0; registry restored and identical in every run.

## Reviews (findings and what was done)

One refute-first review: no MUST, no SHOULD. NOTE 1 (the link rule asked for every reparse file
even when unused) - done, asked only when compression, encryption or times change; NOTE 2 (a tag
comment wrong; add WOF / WSL symlink checks) - done; NOTE 3 (Convert through a file link) -
measured: `ReplaceFileW` fails with 1464, nothing changes - recorded in the fix-log, no Inbox item;
NOTE 4 (encryption not driven) - person step. All checks re-run after the changes (numbers above).

## Owed to a person (with the new person-step items)

- `check-change-attributes-refuses-encrypting-a-file-link` - Check that Change Attributes refuses
  to encrypt or decrypt a file symbolic link (272) (related to 253's junction check).

## New Inbox items (slug - title)

- `check-change-attributes-refuses-encrypting-a-file-link` - Check that Change Attributes refuses
  to encrypt or decrypt a file symbolic link (272) (person step).
