# Closing report - 324-undelete-unknown-volume
Backlog item: undelete-skips-its-same-partition-warning-when-the-target - Undelete skips its same-partition warning when the target volume cannot be told
Outcome: closed

## What changed

- `src/common/salsamevolume.h` (new, header-only): the same-volume guard - the core's answer and
  its estimation flag; an unsure "different" is re-decided by the volume serial numbers of both
  paths' nearest existing folders (103's `SalGetFileIdentityW`, wide, `\\?\` form, any length,
  stepping up only on "not found"); an unreadable serial counts as the same volume.
- `src/plugins/undelete/fs2.cpp`: `UndPathsMayShareVolume` used by the `IDS_SAMEPARTITION` warning
  (`CopyOrMoveFromFS`) and both checks of View's temporary folder (`GetTempDirOutsideRoot`).
- `src/saltests/saltests.cpp`: `TestSameVolume324`.
- Unchanged: the core's `PathsAreOnTheSameVolume`, the plug-in interface, UI strings, stored data.

## Measurements (before / after, commands)

- Before (main 3162d8b2): `python -I specs\324-undelete-unknown-volume\probe\measure_volume.py <fixture under %TEMP%>`
  - a junction `Zálohy` to the volume root: wide API -> the volume, code-page API with UTF-8 (what
  the core calls) -> error 2; a junction to a volume-GUID folder -> both fail (206). Code trace:
  the core's walk may not cut past such a folder -> one volume unreadable -> "different" with the
  estimation flag -> no warning.
- After: the same API facts (the core is unchanged by design); the plug-in's decision on those
  paths answers "same" (saltests real-folder rows), and "different" for another fixed volume.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64). No resources changed - `build.cmd full` not needed.
- `saltests.exe` -> `saltests: 27848 checks, 0 failed` (`TestSameVolume324` runs 55 checks).
- Negative controls: the core's answer alone -> 6 failed; a read of the link itself instead of its
  target -> 2 failed (the cross-volume rows of review 1).
- GUI: NOT DRIVEN (Undelete needs an elevated program to open a volume) - person step below.

## Reviews (findings and what was done)

Review 1 (refute-first agent): no MUST. SHOULD 1 taken (a junction to a second volume's root, so
the test proves the identity read follows links - the reviewer's mutant had passed). NOTEs: extra
warnings for serial-0 / unreachable volumes accepted (the spec's fail-closed choice); an unreachable
UNC target costs one failed open (~1.25 s) before the warning; formatting and the check count fixed;
a certain-but-wrong core answer for a 259-byte target is not reachable through Undelete (it refuses
such targets). Details: `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `check-the-undelete-same-partition-warning-for-a-target-in-an` - the restore and View through
  the elevated Undelete GUI with a volume mounted at an accented folder (same setup as
  `undelete-mount-points-and-efs-114-115`).

## New Inbox items (slug - title)

- `the-core-reads-volume-names-with-the-code-page-api-on-utf-8` - The core reads volume names with
  the code-page API on UTF-8 paths.
- `check-the-undelete-same-partition-warning-for-a-target-in-an` - Check the Undelete
  same-partition warning for a target in an accented mount folder (person step).
