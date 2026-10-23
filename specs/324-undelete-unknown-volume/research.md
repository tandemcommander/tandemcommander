# Research - 324 undelete-unknown-volume

## R1 - Is the fail-open reachable at HEAD (3162d8b2)?

- Decision: yes. Measured with `probe/measure_volume.py` (Python ctypes, fixture under `%TEMP%`,
  no admin): a junction `Zálohy` -> `\??\Volume{C}\` gives the volume for
  `GetVolumeNameForVolumeMountPointW`, error 2 for `GetVolumeNameForVolumeMountPointA` with the
  UTF-8 bytes (the core is built without `UNICODE`, `salamdr1.cpp` calls the A function); a
  junction -> `\??\Volume{C}\...\tgt` fails for both (error 206). `GetReparsePointDestination`
  types a `\??\Volume` junction as a mount point, `ResolveLocalPathWithReparsePoints` then sets
  `cutResPathIsPossible = FALSE`, `GetSubstPathVolume` does not apply -> `numOfGetVolNamesFailed
  = 1` -> FALSE with `resIsOnlyEstimation = TRUE`.
- Alternatives: a virtual drive without a mount-manager name (both paths fail -> the root
  comparison says "same" - not the defect); a long path (the walk cuts to the root - answered).

## R2 - Where to fix

- Decision: in the plug-in. The core function is a plug-in service (`spl_gen.h`); changing its
  answer changes the contract for every plug-in (maintainer-owned). The plug-in already gets the
  estimation flag.
- Alternative: "estimation + different = same" alone (item *Notes*). Rejected: the core is
  always unsure for network targets, so every restore to a share (the recommended practice) would
  warn - and "Don't show this again" would then switch the real warning off too.

## R3 - How to tell the volume when the core cannot

- Decision: the volume serial number of an open handle (`GetFileInformationByHandle`, and
  `FileIdInfo`'s 64-bit serial when both sides have it) of each path's nearest existing folder,
  through 103's `SalGetFileIdentityW`. An open follows junctions, mount folders, symbolic links
  and subst drives the way the restore's writes will. Unknown: the open failed with anything but
  "not found", only attribute data was read, or the serial is 0.
- Equal serials of two different volumes (a cloned disk) answer "same" - an extra warning, the
  safe side.
- Alternatives: `GetFinalPathNameByHandleW(VOLUME_NAME_GUID)` - fails on shares and on volumes
  without a mount-manager name, needs more code; the W version of the core's walk - fixes only the
  non-ASCII case, not the volume-GUID junction.

## R4 - The target does not exist yet

- Decision: step up to the parent only on `ERROR_FILE_NOT_FOUND` / `ERROR_PATH_NOT_FOUND`, never
  above the path's root (`\\?\X:\`, `\\?\UNC\srv\share\`, `\\?\Volume{...}\`); the restore
  creates the missing folders below the nearest existing one, so that folder's volume is where
  the data goes.

## R5 - Message

- Decision: no new text. `IDS_SAMEPARTITION` begins "It seems you are undeleting to the same
  logical disk" - true for "cannot tell" as well; the temporary-folder question is unchanged.
