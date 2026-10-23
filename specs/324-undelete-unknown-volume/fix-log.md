# Fix log - 324-undelete-unknown-volume

Backlog item `undelete-skips-its-same-partition-warning-when-the-target`. HEAD0 = 3162d8b2.

## Measurement (before, on main 3162d8b2)

Sites (found by name):
- `src/plugins/undelete/fs2.cpp` `CopyOrMoveFromFS` - `PathsAreOnTheSameVolume(targetPath, Root, NULL)` -> `IDS_SAMEPARTITION`;
  `GetTempDirOutsideRoot` - `PathsAreOnTheSameVolume(Root, path, NULL)` and `(Root, ConfigTempPath, NULL)`.
- `src/salamdr1.cpp` `PathsAreOnTheSameVolume` - `numOfGetVolNamesFailed == 1` -> FALSE, `resIsOnlyEstimation` TRUE.
- Only caller of the plug-in service in the tree: Undelete (grep `PathsAreOnTheSameVolume` in `src/`).
- `undelete=on` in `plugins.cfg` (shipped). `Root` = `GetVolumePathNameW` of the panel path (a drive root
  or a mount folder).

Command (PowerShell, not elevated):

```text
python -I "$env:TEMP\tcvol_measure\measure_volume.py" "$env:TEMP\tcvol_measure\fx1"
volume of C:\ = \\?\Volume{42005f8f-a7e6-42c7-9604-d40745a469d2}\
ROOT         W=\\?\Volume{42005f8f-...}\  A(UTF-8)=\\?\Volume{42005f8f-...}\
J1 jsub\     W=FAIL(206)  A(UTF-8)=FAIL(206)
J2 Zálohy\   W=\\?\Volume{42005f8f-...}\  A(UTF-8)=FAIL(2)
J1 write lands in ...\fx1\tgt : True
```

(the script is kept as `probe/measure_volume.py`.) J2 is a junction named `Zálohy` to the volume
root `\??\Volume{C}\` - what a mount folder is; J1 a junction to a volume-GUID subfolder.

Code trace for target `...\fx1\Zálohy\restore`, Root `C:\`: `GetCurrentLocalReparsePoint` (wide)
finds `...\Zálohy\`; `GetReparsePointDestination` types a `\??\Volume` junction as MOUNT POINT and
returns `Volume{...}\`; `ResolveLocalPathWithReparsePoints` sets `cutResPathIsPossible = FALSE`;
`GetVolumeNameForVolumeMountPoint` = the A function (the core project has no `CharacterSet`, no
`UNICODE`) with the UTF-8 bytes fails (measured error 2); no cut allowed; `GetSubstPathVolume`
FALSE (not a subst) -> `numOfGetVolNamesFailed = 1`; Root `C:\` read -> FALSE ("different"),
estimation TRUE. The same for J1 with any name. Restoring volume X into a mount folder of X named
outside ASCII therefore skips the warning; View's temporary folder check likewise.

End to end through Undelete: NOT DRIVEN - opening a volume needs an elevated program (the run's
shell is not elevated: `IsInRole(Administrator)` = False).

`BL verify` recorded on main before the branch.

## Decisions

- Fix in the plug-in, the core service unchanged (plug-in contract; item *Notes*).
- "different" + estimation -> decide by the volume serial of each path's nearest existing folder
  (103's `SalGetFileIdentityW`); unreadable -> same (fail closed). "same" and a certain "different"
  unchanged. No new UI string.
- Not "estimation = same" alone: the core is always unsure for network targets - every restore to a
  share would warn (research R2).

## Implementation

- `src/common/salsamevolume.h` (new, header-only, wide API, on 103's `salsamefile.h`):
  `SalVolumeSerialMatch`, `SalVolumeGuardSame`, `SalVolumeIdentityStepsUp`, `SalWPathRootLength`,
  `SalWPathCutLast`, `SalGetNearestVolumeIdentityW`, `SalVolumeGuardForPaths`.
- `src/plugins/undelete/fs2.cpp`: `UndPathsMayShareVolume(path1, path2)` - the core's answer with
  its estimation flag; a sure answer or "same" returns as before; an unsure "different" goes to
  `SalVolumeGuardForPaths` on `SplU8ToWExtAlloc` forms. Used by the `IDS_SAMEPARTITION` test of
  `CopyOrMoveFromFS` and both tests of `GetTempDirOutsideRoot` (argument order unchanged).
- `src/saltests/saltests.cpp`: `TestSameVolume324` - 55 checks run (52 before review 1; the
  fix-log first said 41, counting CHECK lines, not loop iterations): the 12-row decision table,
  serial match, step-up errors, root length / cut, and real folders under `%TEMP%` (junction
  `Zálohy` -> the volume root, junction `jsub` -> a volume-GUID folder, missing targets below both,
  a missing drive letter, another fixed volume - D: here - and, from review 1, a junction
  `ZálohyX` on the temp volume to the other volume's root).
- No UI string, dialog, plug-in interface or core change -> no `.slt` refresh needed.

## Checks

- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64).
- `saltests.exe` -> `saltests: 27845 checks, 0 failed` (exit 0); the second-fixed-volume row ran.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- **Negative control**: `SalVolumeGuardSame` returning the core's answer alone (an inserted
  `if (TRUE) return FALSE;` after the "same" line) -> `saltests: 27845 checks, 6 failed`: the two
  fail-closed table rows ({FALSE, TRUE, simUnknown}, {FALSE, TRUE, simEqual}), the NULL-path row,
  both junction fixture rows and the missing-drive row. Restored -> 0 failed.
- `probe/measure_volume.py` re-run (after): the same API facts (J2 `W=` volume, `A(UTF-8)=FAIL(2)`;
  J1 both FAIL(206)) - the core is unchanged by design; the plug-in decides past it.
- NOT DRIVEN: the restore and View through the Undelete GUI - opening a volume needs an elevated
  program; owed to a person (person-step item at closing).

## Inbox

- `the-core-reads-volume-names-with-the-code-page-api-on-utf-8` - the core's A
  `GetVolumeNameForVolumeMountPoint` on UTF-8 paths (measure:324).

## Review

### Review 1 (independent agent, refute-first) - no MUST

Re-ran the measurement (same facts) and saltests (27845 / 0); its own harness against the real
header: a junction on C: to D:'s root - Root D: -> same, Root C: -> different; a ~900-character
missing target with Czech letters below it -> D's serial, nothing cut; a loopback share
(`\localhost\D$`) reports D's serials (now warns - correct); G: (FAT32, has a volume name) is
answered by the core as before; D:/E:/F: distinct serials - no new warning.

- SHOULD 1 (taken): the fixture's junctions all pointed back to the temp volume, so a read that
  opened the link itself instead of following it passed too (the reviewer's mutant
  `SalGetFileIdentityW(w, TRUE, id)`: 0 failed). Added the cross-volume row (junction `ZálohyX` to
  the other fixed volume's root: same against that root, different against the temp root).
  Negative control repeated here: the mutant -> `saltests: 27848 checks, 2 failed` (both new
  rows); restored -> `27848 checks, 0 failed`.
- NOTE 2 (accepted, the spec's fail-closed choice): a serial 0 volume, an unreachable share, a
  source root Windows cannot open now give the warning when the core is unsure; not measurable
  here (no WebDAV / RAW volume).
- NOTE 3 (accepted): an unreachable UNC target now costs one failed open before the warning
  (reviewer: ~1.25 s for a missing host); `TestFreeSpace` touches the same path right after.
- NOTE 4 (taken): the include's comment spacing; the saltests block formatted with clang-format
  (fs2.cpp's remaining clang-format differences, lines ~731 and ~1617, predate this feature).
- NOTE 5 (taken): the check count in this log.
- NOTE 6: `UndPathsMayShareVolume` and the GUI are not covered automatically - person step.
- NOTE 7 (not reachable): a certain-but-wrong core answer is not re-checked (a 259-byte target
  skips the junction walk, `salamdr2.cpp` `ResolveLocalPathWithReparsePoints`); Undelete refuses
  targets of 259+ bytes in `AppendPath`, so not reachable through it.

After review 1: `.\build.cmd` BUILD SUCCEEDED, saltests 27848 / 0, encoding guard TOTAL: 0.
