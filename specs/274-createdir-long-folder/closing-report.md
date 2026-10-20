# Closing report - 274-createdir-long-folder
Backlog item: create-directory-refuses-a-relative-name-in-a-folder-whose - Create Directory refuses a relative name in a folder whose path is 260+ bytes
Outcome: closed

## What changed

`src/fileswn5.cpp` `CFilesWindow::CreateDir` (F7 on a disk panel):

- the typed name is joined with the panel path by `SalGetFullName(..., NULL, SAL_MAX_PATH_UTF8)` -
  the default `MAX_PATH` refused every joined path of 260+ bytes although the buffer and the rest
  of the routine take `SAL_MAX_PATH_UTF8` (feature 027);
- the new folder's own name is judged with `SalNameTooLongForFileSystemU8`; over 255 UTF-16 units
  -> "Cannot finish operation because of too long name." (`IDS_TOOLONGNAME`) before anything is
  created (no missing parent either); the dialog comes back.

No new UI string, no plug-in interface, registry or installer change. Other callers of
`SalGetFullName` with the default limit (Pack, Unpack, Make File List and its dialog) have
259-byte buffers - listed in research.md R3, not changed.

## Measurements (before / after, commands)

Probe `probe/createdir274_probe.ps1` on the hidden desktop (`tools/run_on_hidden_desktop.ps1`,
command in fix-log.md):

| Row | Before (449f35fc) | After |
|---|---|---|
| SHORT "nd", 45-byte folder | PASS | PASS |
| REL "nd", 288-byte folder | FAIL "path too long" | PASS created |
| CJK 100 letters, 288-byte folder | FAIL "path too long" | PASS created (300-byte name) |
| U255 255 letters, short folder | FAIL "path too long" | PASS created (765-byte name) |
| U256 256 letters | FAIL wrong reason | PASS "too long name" |
| LIMIT 98,244-byte relative path | PASS "path too long" | PASS "path too long" |
| MULTI `a\` + 256 letters (added after review) | - | PASS "too long name", no `a` made |

Totals with END rows: 8 / 4 before -> 14 / 0 after (`probe/result_before.txt`,
`probe/result_after.txt`). Negative control (name check disabled): U256 FAIL with Windows' "(123)
invalid name" (`probe/result_negative_control.txt`); the reviewer's negative control (the
`nameBufSize` argument removed): 7 / 5.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `build.cmd` (Debug x64) -> `BUILD SUCCEEDED`
- `saltests: 24859 checks, 0 failed`
- probe 14 PASS / 0 FAIL / 0 NOT DRIVEN; registry restored and identical; fixture removed

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD - the probe did not prove "no missing parent is
created" -> row MULTI added, probe re-run 14 / 0. NOTE 1 - FR-004 wording vs the name check on
absolute paths -> spec corrected. NOTE 2 (stale focus name between attempts, harmless,
pre-existing) - recorded. NOTE 3 (the create-folder question cuts a long path inside a letter,
pre-existing) -> Inbox. NOTE 4 / 5 - recorded limits.

## Owed to a person (with the new person-step items)

Nothing: every row was driven on the hidden desktop (no keyboard, clipboard or printer needed).

## New Inbox items (slug - title)

- the-question-whether-to-create-a-missing-folder-cuts-a-long - The question whether to create a
  missing folder cuts a long path inside a letter
