---
title: Undelete skips its same-partition warning when the target volume cannot be told
type: bug
status: open
severity: 5
area: data-safety
source: measure:301
who: both
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Undelete skips its same-partition warning when the target volume cannot be told

## Problem

Before it restores files, the Undelete plug-in warns when the restore target is on the volume the
files are being recovered from: writing there can overwrite the clusters of files not yet
recovered. It asks the core's `PathsAreOnTheSameVolume`, and that function answers "different
volumes" whenever it can read the volume name of only one of the two paths. The warning then
fails open: the user restores onto the same volume without being told. The same answer decides
whether the temporary folder of a restore may be on the source volume. Feature 301 closed the
case that was measured - a path on a subst drive whose resolved path does not fit 260 bytes now
gets its volume from the whole wide subst target (`GetSubstPathVolume`, probe
`specs/301-subst-target-whole/probe/subst_probe.ps1` rows VOL / MOVE) - but the fail-open rule
itself stays for any other path whose volume name cannot be read.

## Evidence

At ab2dd996 (branch `301-subst-target-whole`):

- `src/plugins/undelete/fs2.cpp:1414` - `if (!ConfigDontShowSamePartitionWarning && !Volume.IsImage && SalamanderGeneral->PathsAreOnTheSameVolume(targetPath, Root, NULL))` shows `IDS_SAMEPARTITION`; `fs2.cpp:1512` / `:1514` - the same test for the temporary folder.
- `src/salamdr1.cpp:1395` `PathsAreOnTheSameVolume` - `if (numOfGetVolNamesFailed == 1 || strcmp(p1Volume, p2Volume) != 0) ret = FALSE;` (one volume name unreadable = "different").
- `src/salamdr2.cpp` `ResolveSubsts` - returns FALSE and leaves the path unresolved when the resolved path or (301) the subst target does not fit `MAX_PATH`; `GetVolumeNameForVolumeMountPoint` then fails for `Z:\...` and every parent up to the subst root - since 301 the walk's failure falls back to `GetSubstPathVolume` (the whole wide target) in `PathsAreOnTheSameVolume`, `HasTheSameRootPathAndVolume` and `GetResolvedPathMountPointAndGUID`.
- Measured in feature 301 (scratch PowerShell, subst Q: to an 80-CJK-letter folder under C:): `GetVolumePathNameW("Q:\x")` returns `Q:\x\` and `GetVolumeNameForVolumeMountPointW` fails for it and for `Q:\` - Windows gives no volume for a subst path.

## Expected

A "same volume?" answer that guards data (the Undelete warning, the temporary folder of a restore)
fails closed: when the volume of either path cannot be told, the plug-in treats the paths as the
same volume (shows the warning / asks for another temporary folder) - or the core resolves the
volume of a subst path without a `MAX_PATH` buffer (e.g. the subst target's volume through a wide,
whole path) so the answer is known.

## Notes

- Not verified end to end: Undelete needs an elevated program to open a volume. After feature
  301 no reachable case is known (candidates not checked: a virtual drive without a mount-manager
  volume name, a path the walk cannot reach); found by reading.
- `PathsAreOnTheSameVolume` is also a plug-in API (`spl_gen.h`) with `resIsOnlyEstimation`; a fix
  inside the plug-in (treat "estimation" + failure as same) may be the smaller change - the core's
  answer is also used for the move decision, where "different" is the safe side.
- Severity 5: the consequence would be the 7-8 band (recoverable data overwritten without the
  warning), lowered because no reachable case is known after feature 301.

## Log

- 2026-10-22 — created (source measure:301)
- 2026-10-22 — severity 7 -> 5: feature 301 closed the measured subst case (review 1)
- 2026-10-22 — moved to Next position 10
