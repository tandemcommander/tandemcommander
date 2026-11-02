# Fix log - 399-zip-symlink-archive

Backlog item `zip-cannot-update-an-archive-reached-through-a-symbolic-link`.

## Measurement before (main at 2a5b7d40)

- `.\build.cmd` -> up to date (Debug x64).
- New probe `probe/zipsymlink_probe.ps1` (driver of 320's `zipreplace_probe.ps1`, library of 098),
  run on the hidden desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ..."
  ```

  Result `probe/result_before.txt`: **14 PASS / 4 FAIL**, registry restored and identical, fixture
  removed.
  - FAIL add-symlink, add-relsymlink, del-symlink, del-relsymlink: the ZIP box "Cannot replace
    original archive with temporary working file. Archive was not changed.", the real archive
    unchanged, the link still the link, nothing new.
  - PASS add-plain / del-plain, add-junction / del-junction (a directory junction in the folder part:
    the real archive updated - the item's "not verified" note answered: only a file link as the last
    component fails), add-symlink-locked (real archive held with sharing read + write: the message,
    nothing changed).
- How the routes name such an archive: Pack (the typed name, relative to the panel), the panel's
  Change Directory into the archive and Delete inside it all give the plug-in the link's path as
  `ZipName`; `CZipPack::CreateTempFile` makes `Sal*.tmp` in the folder of `ZipName` (next to the
  link) and `ReplaceArchiveWithTemp` -> `SalReplaceWithTempW(ZipName, ...)` -> `ReplaceFileW` onto
  the link fails with 1464 -> `srnKeepTarget` -> the temporary file deleted, `IDS_ERRRESTORE`.
- `ZipAttr` is read with `SalGetFileAttributes(ZipName)`: on a link that is the link's own
  attributes (`ARCHIVE | REPARSE_POINT`), not the real archive's.

## Consumers (fix protocol)

- `CZipPack::CreateTempFile` - called only from `PackNormal` (add.cpp) and `DeleteFromArchive`
  (add_del.cpp), both with `ZipFile` open and `Config.BackupZip` on.
- `CZipPack::ReplaceArchiveWithTemp` - the same two sites, after `CreateTempFile`.
- `TempName` is otherwise used by `PackMultiVol` / `NextDisk` (volume names, not touched here).
- `SalReplaceWithTempW` other callers (core `cfgimpdlg.cpp`, `salamdr2.cpp`; PictView `saveas.cpp`,
  `thumbs.cpp`; SFTP `operats.cpp`) - not changed (the helper itself is not changed).

## Decisions

- Update the real archive (item *Expected*, first option) - no new string.
- Follow only a name that is itself a name-surrogate reparse point and not a folder (a file symbolic
  link); everything else unchanged (spec Clarifications).
- Unresolvable link -> as today (fails safe with the true message).
