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
- `src/saltests/saltests.cpp`: `TestSameVolume324` - 41 checks: the 12-row decision table, serial
  match, step-up errors, root length / cut, and real folders under `%TEMP%` (junction `Zálohy` ->
  the volume root, junction `jsub` -> a volume-GUID folder, missing targets below both, a missing
  drive letter, another fixed volume - D: here).
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
