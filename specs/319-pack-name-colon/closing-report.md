# Closing report - 319-pack-name-colon
Backlog item: pack-writes-the-archive-into-a-hidden-data-stream-when-its - Pack writes the archive into a hidden data stream when its name holds a colon
Outcome: closed

## What changed

- `src/common/salpackname.h`: new pure rule `SalPackNameHasStreamColon(fullName)` - a drive prefix
  (`X:` as the first two bytes) skipped, the last part after the last `\` or `/`, TRUE when it holds
  `:`. Header-only, UTF-8 bytes.
- `src/fileswn7.cpp` `CFilesWindow::Pack`: after `SalGetFullName`, a name for which the rule is TRUE
  is refused unconditionally with "The path specified is invalid." (`IDS_PATHISINVALID`) and the
  dialog again - next to 318's trailing dot / space / device-name refusal (which stays gated by
  `FileExists`). No new string, no plug-in change.
- `src/saltests/saltests.cpp`: `TestPackName319`, 32 checks.
- `specs/319-pack-name-colon/probe/pack319_probe.ps1`: 21 rows; snapshots include alternate data
  streams.

## Measurements (before / after, commands)

- Before (e9c35c2e, `probe/result_before.txt`): 6 FAIL / 18 PASS - `report:zip`, `rep:x.zip`,
  `<src>\abs:x.zip` created an empty base file + the archive in its stream; `report:zip` next to an
  existing `report` attached a stream; Add into an existing stream archive changed it and left
  `Sal5C0.tmp`; `plain/rep:x.zip` reached the ZIP plug-in.
- After (`probe/result_after.txt`): 42 PASS / 0 FAIL (12 original rows + the review's 9) - every
  colon row refused at OK, nothing new or changed (streams included); controls (`plain.zip`,
  `<src>\abs.zip`, `C:rel.zip`, the full-width colon) packed; `report.` and the empty entry as before.
- Negative control (`probe/result_negctl.txt`, the rule returning FALSE): 6 FAIL / 18 PASS - the
  probe detects the defect.
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\319-pack-name-colon\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\319-pack-name-colon\probe\pack319_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after-review"`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED (attempt 1 failed - a Bash heredoc collapsed `'\\'`;
  fixed with the editor).
- saltests: 27,540 checks, 0 failed (negative control: 18 failed - exactly the "refused" checks).
- Probe 319: 42 / 0; probe 318 (`probe/regress_318.txt`): 52 / 0; registry restored and identical
  on every run.

## Reviews (findings and what was done)

One refute-first review: no MUST, no SHOULD. NOTE 1 closing steps - done here; NOTE 2 GUI evidence
for the spec's edge cases - the reviewer's 9 rows adopted into the probe, re-run 42 / 0; NOTE 3
`report.zip::$DATA` now refused - covered; NOTE 4 the ZIP plug-in's false "Archive was not changed."
- Inbox item. The reviewer's own call-site negative control failed 4 of 5 rows.

## Owed to a person (with the new person-step items)

Nothing.

## New Inbox items (slug - title)

- zip-says-the-archive-was-not-changed-after-a-failed-replace - ZIP says the archive was not changed after a failed replace, yet it changed and a temp file stays
