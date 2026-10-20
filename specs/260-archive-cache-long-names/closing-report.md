# Closing report - 260-archive-cache-long-names
Backlog item: archive-long-names-cache-folders-tar - Archives: long member names refused by the cache, long folders skipped
Outcome: closed

## What changed

- **F3 / F4 of long archive member names** - the disk cache's temporary copy is limited by the
  Windows path (259 UTF-16 units) instead of 259 bytes for the core's own F3 / F4 of archive members
  (`src/common/salcachename.h` `SalCacheTmpPathFitsU8`; `src/cache.cpp` / `cache.h`
  `CDiskCache::GetName(..., longTmpPath)`; `src/fileswn5.cpp`, `src/fileswn6.cpp`). The plug-in
  disk-cache services and the User Menu keep the byte rule. Feature 095's limit of the name handed
  to the archiver (the member's path inside the archive under 520 bytes) stays.
- **The edit's way back** (`src/salamdr3.cpp`): `CheckAndPackAndClear` holds the copy's path whole
  (was cut at 620 bytes - the edit could be dropped as "unchanged"); `CopyFilesTo` builds the names
  on the heap and says "too long name" only for what the shell call cannot take; the start-up
  cleanup walk `_RemoveTemporaryDir` takes long names (it skipped them - a crashed session's
  long-named copy stayed for good), bounded at 128 levels.
- **gzip stored name** (tar plug-in: `gzip/gunzip.cpp`, `fileio.h/.cpp`, `untar.cpp`): read whole
  (64 KiB bound); a name over 255 UTF-16 units refuses the .gz with the system's "(206) The filename
  or extension is too long." - never listed or extracted under a cut name.
- **Long folders inside archives**: measured - every route already reports them; no change.

## Measurements (before / after, commands)

- At b8d1f7d0 on `main`: `specs/222-name-length-units/probe/editname222_probe.ps1` (hidden desktop)
  row LONG - F4 of a 274-byte / 94-unit member: "...resulting filename is too long."; DIRLONG
  reported.
- `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\260-archive-cache-long-names\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\260-archive-cache-long-names\probe\cache260_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`
  - before (build without the change, 7 rows): **10 PASS / 4 FAIL** - VIEWLONG, EDITLONG refused;
    GZLONG not extracted ("Expanded string is too large."); GZOVER opened under the cut name.
  - after (final build, 8 rows - ARCCAP added by review 1): **16 PASS / 0 FAIL** - the viewer
    opens; the edit round trip leaves one member, whole name, edited content; ARCCAP (604 bytes)
    and OVERLIMIT refused as stated; GZLONG extracted under the whole name; GZOVER refused, nothing
    written; controls pass.
- Regression: 222's probe 10 / 0 (`probe/regress_222.txt`; its LONG row now starts the editor).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64)
- `saltests` -> `saltests: 24559 checks, 0 failed` (`TestCacheTmpPath260`, 15 checks)
- probe 260: 16 / 0; probe 222: 10 / 0; registry restored identically in every run

## Reviews (findings and what was done)

- Review 1: M1 (FR-001 overclaimed - 095's 520-byte limit) -> limit kept, claims corrected, probe
  row ARCCAP, Inbox item; S1 (the 620-byte fix not driven) -> not drivable (the program regenerates
  its environment from the registry), person step; S2 (plug-ins get longer target joins) ->
  contract note, unrar Inbox item; S3 (the cleanup walk skipped long names) -> fixed; N1 -> Inbox
  item; N2 -> decision item.
- Review 2: no MUST; S-A (the walk unbounded) -> depth bound 128; S-B (items not filed) -> filed;
  notes recorded in the fix-log.

## Owed to a person (with the new person-step items)

- `editing-long-named-archive-members-the-rows-the-feature-260` - the edit-back with a long %TEMP%
  (copy path over 620 bytes), "Copy selected to..." with a long name, the start-up cleanup of a
  long-named copy after a crash.

## New Inbox items (slug - title)

- `f3-f4-refuse-archive-members-whose-path-inside-the-archive` - F3 / F4 refuse archive members whose path inside the archive has 520 bytes or more
- `unrar-plug-in-a-member-name-over-259-bytes-overflows-a-stack` - unrar plug-in: a member name over 259 bytes overflows a stack buffer on F3 / F4
- `focusing-an-archive-member-with-a-very-long-name-shows` - Focusing an archive member with a very long name shows "Expanded string is too large." twice
- `a-gz-file-whose-stored-name-is-too-long-for-windows-refuse` - A .gz file whose stored name is too long for Windows: refuse it or use the archive name (decision)
- `editing-long-named-archive-members-the-rows-the-feature-260` - Editing long-named archive members: the rows the feature-260 probe could not drive (person step)
