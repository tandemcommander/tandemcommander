# Fix log - 300-volume-label-wide

Backlog item `volume-label-written-through-ansi-api` - Drive Information writes the volume label
through an ANSI API. Run started at `main` 82bf0dac (2026-10-22).

## Measurement before (at 82bf0dac)

- Site: `src/dialogs3.cpp` `CDriveInfo::Validate` -
  `BOOL res = SetVolumeLabel(volumePathWithBackslash, newName);` after
  `SalGetWindowTextU8(edit, newName, MAX_PATH)`. Grep: the only `SetVolumeLabel` call in `src/`
  (core and plug-ins); no shim.
- The core has no `UNICODE`: no project under `src/vcxproj` sets `CharacterSet` except `tserver`
  → the call is `SetVolumeLabelA`.
- Reachable: `CM_DRIVEINFO` (menu `menu4.cpp`, toolbar `toolbar4.cpp`, `mainwnd3.cpp`, status bar
  `stswnd.cpp`, plug-in command `SALCMD_DRIVEINFO` `zip.cpp`) → `CFilesWindow::DriveInfo`
  (`fileswn2.cpp`, disk or archive panel) → `CDriveInfo::Execute` → OK → `Validate`, when the
  typed label differs from the one shown (069's comparison).
- What the drive would receive: `Zálohy` in UTF-8 is `5A C3 A1 6C 6F 68 79`; read in code page
  1250 (the machine's ACP; `HKLM\...\Nls\CodePage\ACP` = 1250) it is `ZĂˇlohy` (code points
  90,258,711,108,111,104,121) - PowerShell `[Text.Encoding]::GetEncoding(1250).GetString(...)`.
- Checker: `ansi-api-on-utf8-path` is a report-only draft rule (`DRAFT_RULES`, not in
  `PROMOTED_FROM_DRAFT`, never part of `--strict`). `python tools/check_encoding.py --rule
  ansi-api-on-utf8-path` → `TOTAL: 39`. With `SetVolumeLabel` added to `ANSI_NAME_API` in
  memory (the source exec'd with the alternation extended): 40 in the core, the new hit
  `dialogs3.cpp:1341: ... SetVolumeLabel(volumePathWithBackslash, newName);`; `--plugins` 76,
  no `SetVolumeLabel`.
- Not driven: the session is not elevated (`IsInRole(Administrator)` = False) and the machine has
  only fixed drives C, D, E, F (`Get-Volume`) - no removable drive; a VHD needs admin. The real
  write is a person step.

## Analyze (one pass)

0 CRITICAL, 0 HIGH. MEDIUM F1 fixed (the message is quoted as the real string "Unable to change
drive label."). LOW C1 (empty label not drivable) → part of the person step; LOW C2 (FR-006, no
UI string) holds by construction - no `.rc2` / `.rh2` change; LOW U1 (the probe rows pass before
and after - they guard the error path, the import table proves the fix) - accepted, stated here.

## Probe before (HEAD build 06:09, = 82bf0dac sources)

`probe/vol300_probe.ps1` on the hidden desktop → `probe/result_before.txt`: PASS 6, FAIL 0,
NOT DRIVEN 0 (`vol-fail`: "Unable to change drive label. Error: (5) Přístup byl odepřen.", the
dialog stays, the label of C: unchanged ''; `vol-same`: closes, nothing asked; `vol-long`: "The
path specified is too long."). Registry restored, SHA-256 identical. As planned these rows do
not show the defect (an unelevated write fails either way).

## Change

- `tools/check_encoding.py` `ANSI_NAME_API`: `SetVolumeLabel` added. Report
  `--rule ansi-api-on-utf8-path` on the unchanged source: 40, the new hit
  `dialogs3.cpp:1341 ... SetVolumeLabel(volumePathWithBackslash, newName);`; `--strict` 0.
- `src/dialogs3.cpp` `CDriveInfo::Validate`: `pathW` / `nameW` = `SalU8ToWAlloc` of the volume
  path and the label; either NULL → nothing written, `err` = `ERROR_NOT_ENOUGH_MEMORY` when the
  failed string's size query succeeds, else `ERROR_NO_UNICODE_TRANSLATION`, then the existing
  message + `ErrorOn`; otherwise the panels' hands-off, `SetVolumeLabelW(pathW, nameW)`,
  `GetLastError`, hands-off ends. Both freed. An empty label converts to `L""` (the size query of
  `""` is 1) - written as empty, as before.

## Measurement after

- Build: `.\build.cmd` → `BUILD SUCCEEDED`. **Trap**: `dumpbin /imports` of this incremental
  Debug link still listed `5BC SetVolumeLabelA` next to `5BD SetVolumeLabelW`, although no
  object referenced the A name (`dumpbin /symbols dialogs3.obj` → only
  `__imp_SetVolumeLabelW`; a byte search of all 174 core `.obj` files and the `.lib` files under
  `src/` found no `SetVolumeLabelA`). `.\build.cmd rebuild` (clean link) → only
  `5BD SetVolumeLabelW`. The stale entry was the incremental linker's (`LinkIncremental` true in
  Debug); the import check must be read from a clean link.
- Checker: `--rule ansi-api-on-utf8-path` → `TOTAL: 39`, no `SetVolumeLabel` line (back to HEAD's
  count); `--plugins` 76, none; `--strict` → `TOTAL: 0 finding(s)`.
- Negative control: `python specs/300-volume-label-wide/probe/checker_negative_control.py` (the
  rule over a scratch tree holding `dialogs3.cpp`): fixed source 0 hits, the old call put back
  1 hit (`dialogs3.cpp:1356 ... res = SetVolumeLabel(volumePathWithBackslash, newName);`) → PASS.
- `saltests`: `saltests: 26443 checks, 0 failed`, exit 0.
- Probe after (clean-rebuilt exe) → `probe/result_after.txt`: PASS 6, FAIL 0, NOT DRIVEN 0, the
  same facts as before; registry restored, SHA-256 identical.

## Owed to a person

The real write (the item's `who: both`): on a USB stick, or a VHD in an elevated program -
Drive Information, label `Zálohy`, OK → Explorer shows `Zálohy` (0.1.10: `ZĂˇlohy`); open Drive
Information again → the field shows `Zálohy`; clear the field, OK → the label is removed.

## Review

Review 1 (independent agent, refute-first, at 124e1da5): **no MUST**. It re-measured the import
table (only `5BD SetVolumeLabelW`), the checker (39 / strict 0 / plug-ins 76), the negative
control (PASS; `main`'s checker on the old call gives 0 hits, so the control depends on the
change; `SetVolumeLabelA(...)`, `::SetVolumeLabel(VolumePath, newName)` and a call split over
lines are each reported), `saltests` 26443 / 0 failed, clang-format clean; enumerated the callers
(the only call; every route ends at `CFilesWindow::DriveInfo` → `CDriveInfo::Validate`); confirmed
the empty label → `L""`, `err` set on both branches, hands-off only around the real call, 069's
comparison and 270's refusal kept.

- S1 the checker addition is report-only, `--strict` would not catch a returning call → inside
  scope as wording: US3 and SC-002 now say report-only (the item asked for the list entry; the
  rule's strictness was settled in *Clarifications*). No strict rule added.
- S2 no runtime evidence for FR-002 (a non-ASCII mount-folder path) → accepted: FR-002 is proven
  by the import table and by reading (both strings go through `SalU8ToWAlloc` to the W call). The
  suggested junction test does not discriminate: `MyGetVolumeInformation` resolves a junction to
  its target volume's root (ASCII), and a real non-ASCII mount folder needs admin to create.
- N3 `GetDiskFreeSpaceEx` (A) with the same UTF-8 path in `CDriveInfo::Transfer` - display only
  (falls back to the cluster-based figures); one of the 39 report-only hits 068 classified - not
  recorded as an item.
- N4 the label field is a code-page edit: a label outside the code page is shown as `?` and an
  edit writes the `?` back → new Inbox item
  `drive-information-turns-a-volume-label-outside-the-code-page` (review:300); the new code
  comment no longer says "never written in another form" (it now names the field's limit).
- N5 the volume path in fixed `MAX_PATH` buffers (pre-existing); a cut path names no existing
  folder, the write fails - not recorded.
- N6 the rule matches only UTF-8-looking identifiers (`SetVolumeLabel(root, label)` is not
  reported) - inherent to the heuristic.
- N7 CHANGELOG entry and person step owed at closing - done at closing.

After the comment and spec edits: `.\build.cmd` → `BUILD SUCCEEDED`; `--strict` → `TOTAL: 0`.
No second review: review 1 had no MUST finding.
