---
title: The core reads volume names with the code-page API on UTF-8 paths
type: bug
status: new
severity: 3
area: encoding
source: measure:324
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [undelete-skips-its-same-partition-warning-when-the-target]
depends-on: []
reason: -
---

# The core reads volume names with the code-page API on UTF-8 paths

## Problem

The core is built without `UNICODE`, so its calls of `GetVolumeNameForVolumeMountPoint` are the
code-page (A) function - and they get the core's UTF-8 paths. A mount folder whose path holds a
character outside ASCII has no volume name for the core: the volume checks end on "cannot tell"
(`"fail"` / `numOfGetVolNamesFailed`), Drive Information's mount-point line and the SSD test of
the path find no volume. This breaks the standing rule "never pass UTF-8 paths to an A API"
(066); `tools/check_encoding.py` does not list the function.

## Evidence

At 3162d8b2 (found while measuring feature 324):

- `src/salamdr1.cpp` `HasTheSameRootPathAndVolume` (two calls) and `PathsAreOnTheSameVolume` (two
  calls): `GetVolumeNameForVolumeMountPoint(ourPath, ...)` with `ourPath` from
  `ResolveLocalPathWithReparsePoints` (UTF-8).
- `src/salamdr7.cpp` `GetResolvedPathMountPointAndGUID`: `GetVolumeNameForVolumeMountPoint(resolvedPath, guidP, ...)`;
  callers `IsPathOnSSD` (salamdr7.cpp), Drive Information (`src/dialogs3.cpp`, `IDT_MOUNTPOINT`),
  Undelete (`fs2.cpp`, `dialogs.cpp`) through the plug-in service.
- `src/vcxproj/salamand.vcxproj` has no `CharacterSet` (no `UNICODE`).
- Measured (feature 324, `specs/324-undelete-unknown-volume/probe/measure_volume.py`, no admin): a
  junction named `Zálohy` to the volume root `\??\Volume{C}\` (what a mount folder is):
  `GetVolumeNameForVolumeMountPointW` returns the volume, `GetVolumeNameForVolumeMountPointA` with
  the UTF-8 bytes fails with error 2.

## Expected

The volume name of a UTF-8 path is read with the wide function (UTF-8 -> UTF-16 whole, the `\\?\`
form when long, never cut, as `GetSubstPathVolume` of feature 301 does); the checker flags the A
function on UTF-8 paths.

## Notes

- Feature 324 made Undelete's same-volume guard fail closed whatever the cause (volume serials of
  the nearest existing folders); this item removes one cause in the core. The move decision
  (`HasTheSameRootPathAndVolume`) errs to "different volumes" (copy + delete) - slower, not unsafe.
- Not verified: the visible effect in Drive Information for a mount folder named outside ASCII
  (needs admin to mount a volume).

## Log

- 2026-10-23 — created (source measure:324)
