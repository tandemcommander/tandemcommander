# Fix log - 319-pack-name-colon

Backlog item `pack-writes-the-archive-into-a-hidden-data-stream-when-its` (source measure:318).

## Measurement at e9c35c2e (main, before the feature)

Debug x64 build of e9c35c2e (`.\build.cmd`, exit 0, incremental). Probe `probe/pack319_probe.ps1`,
written for the measurement from 318's (`specs/318-pack-name-trailing-dot/probe/pack318_probe.ps1`,
098's library); its snapshot lists every file and folder **and every alternate data stream**
(`FindFirstStreamW` through `\\?\`, contents hashed through `CreateFileW`) - 318's snapshot
(`Directory.GetFiles`) cannot see a stream. First run from a scratch folder under `%TEMP%`, then
copied unchanged:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\pack319_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

Result (`probe/result_before.txt`): **6 FAIL / 18 PASS** (RUN + END rows), registry restored and
identical (SHA-256 CF69145A...). Rows (the ZIP plug-in's "Create New Archive" box answered OK):

- colon-ext `report:zip` - new `src\report` (empty) and the stream `src\report:zip.zip` - FAIL;
- colon-mid `rep:x.zip` - new `src\rep` + stream `src\rep:x.zip` - FAIL;
- colon-exist `report:zip` next to an existing `report` - new stream `src\report:zip.zip`,
  `report`'s main stream unchanged - FAIL;
- colon-stream `report:zip.zip`, `report` already holding a stream `zip.zip` with an archive - the
  "already exists ... add or overwrite?" question, Add, then ZIP "Cannot replace original archive
  with temporary working file. Archive was not changed." - but the stream **changed** and a stray
  `src\Sal5C0.tmp` was left - FAIL;
- colon-abs `<src>\abs:x.zip` - new `src\abs` + stream - FAIL;
- colon-slash `plain/rep:x.zip` - the ZIP plug-in itself "Cannot open or create file." after its
  Create New Archive box, nothing created - FAIL by the item (not refused at OK);
- PASS: colon-dir `sub:x\a.zip` (ZIP "Cannot access file. ... incorrect", nothing created - not this
  item's); ctl-plain (item 0, `plain.zip`); ctl-drive-abs `<src>\abs.zip`; ctl-drive-rel `C:rel.zip`
  (-> `src\rel.zip`); trail-dot `report.` refused (318); ctl-empty.

Reachability: Alt+F5 in a disk panel -> `CFilesWindow::Pack` (`src/fileswn7.cpp`) -> `CPackDialog`
-> OK -> `SalGetFullName(fileBuf, ..., MAX_PATH, TRUE)` (a `:` other than at the second character is
kept; `report:zip` is relative) -> `SalPackNameIsNotKeptAsTyped` (318, no colon rule) -> the packer.

Consumers enumerated (Grep `SalPackName`): `SalPackNameIsNotKeptAsTyped` is called at
`src/fileswn7.cpp` (Pack) and in `src/saltests/saltests.cpp` (`TestPackName318`) only; no plug-in
includes `salpackname.h`.

## Decisions

- R1: the check joins 318's after `SalGetFullName` - same `IDS_PATHISINVALID`, the dialog again.
- R2: `SalPackNameHasStreamColon` - drive prefix `X:` skipped, last part after the last `\` or `/`,
  TRUE when it holds `:`. A colon only in a folder part is not refused (the packer refuses it).
- R3: refused regardless of `FileExists` (an existing stream too) - the item's *Expected*.
- R4: no new string.

## speckit-analyze

No CRITICAL / HIGH. Accepted LOW: C1 the "other panel" option has no own row (absolute name, the
same branch as colon-abs); C2 UTF-8 / leading colon / full-width colon only in saltests; C3 the
probe does not assert the absence of the "already exists" question (the refusal precedes it in
code; colon-stream's "nothing changed" covers the effect).

## Change (T002-T004)

1. `src/common/salpackname.h`: `SalPackNameHasStreamColon(fullName)` - a drive prefix (ASCII letter
   + `:` as the first two bytes) skipped, the last part after the last `\` or `/`, TRUE when it holds
   `:`; header comment extended for 319. Header-only, reads UTF-8 bytes.
2. `src/saltests/saltests.cpp`: `TestPackName319` (32 checks) after `TestPackName318`: refused -
   relative, absolute, root, UNC, after `/`, a leading / trailing / only colon, two colons, UTF-8 and
   CJK names, a name without folder, drive-relative `C:rep:x.zip`, `::$DATA`, a digit or a non-ASCII
   byte before `:`; not refused - `C:\t\report.zip`, `C:report.zip`, `C:`, `C:\`, a colon only in a
   folder part (`\` and `/`), no last part, UNC without colon, the full-width colon U+FF1A, NULL, empty.
3. `src/fileswn7.cpp` `CFilesWindow::Pack`: the refusal after `SalGetFullName` is now
   `SalPackNameHasStreamColon(fileBuf) || (SalPackNameIsNotKeptAsTyped(fileBuf) && !FileExists(fileBuf))`
   - the colon refused unconditionally, the same `IDS_PATHISINVALID` route, the dialog again; the
   comment extended. No new string, no plug-in change.

## Checks after the change

- Attempt 1: `.\build.cmd` BUILD FAILED - the rule was appended to the header with a Bash heredoc,
  which turned the doubled backslash of the character constant (backslash literal) into a single one (C2015 / C2001; CLAUDE.md, 123). Fixed with the editor.
- Attempt 2: `.\build.cmd` BUILD SUCCEEDED, exit 0; `saltests: 27540 checks, 0 failed` (27508 + 32).
- Negative control of the unit checks: the rule's `return strchr(last, ':') != NULL;` replaced by
  `return FALSE;` (a copy kept), rebuilt: `saltests: 27540 checks, 18 failed` - exactly the 18
  "refused" checks. Restored from the copy (SHA-256 identical, D055EBDC...).
- Trap met: `Copy-Item` restored the header with its old time stamp, so the next `.\build.cmd` did
  not recompile - saltests still 18 failed and the probe run then (`probe/result_negctl.txt`) was on
  the **negative-control binary**: 6 FAIL / 18 PASS, the same rows as before the fix. Kept as the
  probe's negative control (the probe detects the defect when the rule is off). The time stamp set to
  now, rebuilt: BUILD SUCCEEDED, `saltests: 27540 checks, 0 failed`.
- Probe (`probe/result_after.txt`): **24 PASS / 0 FAIL** (before 18 / 6); registry restored, SHA-256
  identical. The six colon rows: "The path specified is invalid." in a box titled Pack, the dialog
  again, nothing new, nothing changed (streams included - colon-stream's stream unchanged, no
  `Sal*.tmp`); colon-dir unchanged (the ZIP plug-in refuses it); the controls packed as before
  (`plain.zip`, `abs.zip`, `C:rel.zip` -> `src\rel.zip`); `report.` and the empty entry as before.
- 318's probe (`probe/regress_318.txt`): 52 PASS / 0 FAIL, registry identical.
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- clang-format (VS 2022 LLVM): `salpackname.h` clean; the changed lines of `fileswn7.cpp` clean;
  the new saltests lines re-aligned by clang-format (comments one column), then rebuilt:
  BUILD SUCCEEDED, `saltests: 27540 checks, 0 failed`.

Not driven: external archivers and 7-Zip (the check runs before any packer - read); typing with a
real keyboard (WM_SETTEXT - the dialog reads the same text); "Use the other panel for packing" on (an
absolute name - colon-abs drives the same branch). No person step is owed.

## Review

One independent refute-first review (general-purpose agent, branch HEAD 17053544): **no MUST, no
SHOULD**, four NOTEs.

- Re-ran: build, `saltests: 27540 checks, 0 failed`, encoding guard 0; a copy of the probe with 9
  extra rows: 42 PASS / 0 FAIL, registry identical. Negative control of its own **at the call site**
  (only `SalPackNameHasStreamColon(fileBuf) ||` removed from `src/fileswn7.cpp`, rebuilt): colon-ext
  created `report` + the stream again, colon-stream "Add" + the ZIP error + a changed stream + a stray
  `Sal309.tmp`, the other-panel row created `tgt\L\abs` + stream, `report.zip::$DATA` an empty
  `report.zip`; restored by hash, time stamp set, rebuilt, subset 6/6.
- Callers: `SalPackNameHasStreamColon` only in `CFilesWindow::Pack` and saltests; the check precedes
  the "packed into itself" check, the question and every packer; `\\?\` / `\\.\` names are refused by
  `SalGetFullName` before. Copy / move / drag & drop into an archive open an existing archive only.
- NOTE 1 (closing steps): CHANGELOG, FEATURE-HISTORY, closing report - written at closing.
- NOTE 2 (fixed): the spec's edge cases (other panel, UTF-8 name, full-width colon, trailing `\`)
  had only saltests evidence. The reviewer's 9 rows were adopted into `probe/pack319_probe.ps1` (row
  names without the `rv-` prefix; `-Another` sets "Use the other panel for packing", `<tgt>` the right
  panel's folder; a rooted typed path must lie inside the row's fixture). Re-run
  (`probe/result_after.txt`, overwritten): **42 PASS / 0 FAIL**, registry restored and identical.
  `ctl-fullwidth` packs `report<U+FF1A>zip.zip` with the folder's entries.
- NOTE 3: `report.zip::$DATA` is refused now (before: an empty `report.zip`) - covered by the item's
  rule, row colon-data.
- NOTE 4 -> Inbox item (measure:319): the ZIP plug-in's "Archive was not changed." after a failed
  replace while the archive (a stream here) had changed and a `Sal*.tmp` was left - no longer
  reachable through Pack; other routes not measured.
- A second review was not run (no MUST).
