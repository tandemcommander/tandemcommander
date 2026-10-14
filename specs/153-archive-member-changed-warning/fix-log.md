# Fix log: 153 - the Archive Update dialog warns about a member changed in the archive

Backlog: `specs/NEXT-WORK.md` A.8 (queue 108 entry 2a; 112's review SF1: an untouched tracked copy
is pinned, so after another program changed the member the edit of the old content overwrites
that change "after the usual notice and list" - a per-member warning was the follow-up).

## Before (measured)

Probe `probe/member_changed_probe.ps1` (fixture `probe/arcfix153.py`; the Archive Update list read
with `LB_GETTEXT`). On the build before (`Debug_x64_pre152`, no change of this area since): x.txt's
line is always plain - the rows where the member changed or was removed FAIL, the plain rows PASS
(`probe/result_pre153.txt`).

## Work

- `src/common/salarcedit.h`: `SalArchiveChangedSinceEdit`, `SalEditedMemberFound`,
  `SalEditedMemberChangedInArchive` (+ 20 saltests checks, 21,842 -> 21,862).
- `fileswnd.h`: `CFileTimeStampsArcStamp` in `CFileTimeStampsItem` (+ `ChangedInArchive`),
  `AddFile(..., arc)`, `MarkChangedInArchive`, `GetArchiveFileStamp153`.
- `fileswn6.cpp ExecuteFromArchive`: the member's listed size/time and the archive file's
  time/size taken at the start of the F4 (before anything is extracted).
- `salamdr3.cpp`: `MarkChangedInArchive` before the dialog - archive stamp now; equal = plain; else
  one listing (`PackList` into a temporary `CSalamanderDirectory`) for all items, the member looked
  up by its exact name, else one match by the file system's rule; the listing's plug-in data
  released like `CSalShExtPastedData`. `AddFilesToListBox`: the marked line
  (`IDS_ARCUPDATECHANGEDINARC` 12174, "%s   (changed in the archive since it was opened -
  updating overwrites that change)"), and the list's horizontal extent.
- Translations: `build_langs.cmd --export-templates --module salamand`, `translate.merge`: 1 gap
  per language, 8 languages, 720 DeepL characters, validation failures 0; formal register (no
  "you" in the source). `build.cmd full`: BUILD SUCCEEDED.

## Review (refute-first agent, 2026-10-14)

- **CRITICAL, introduced - fixed:** a failed new listing released the plug-in data although the
  7zip plug-in deletes them on failure and leaves the pointer set (`7zip.cpp`; the contract ignores
  `pluginData` after FALSE): use after free / double delete. Released now only after a successful
  listing (as the panel's failed listing only deletes the directory). **Measured:** rows
  `zip-corrupt`, `7z-corrupt` added; the variant without the guard: `7z-corrupt` FAIL - no dialog,
  a crash report; with it PASS.
- MEDIUM - taken over: the list's horizontal scroll bar never scrolled (nothing set the extent);
  `LB_SETHORIZONTALEXTENT` from the widest line now. Left: a line of a deep name shows its warning
  only after scrolling (the dialog's layout unchanged - a person step looks at it).
- LOW - taken over: an archive that cannot be opened at the update marked everything "changed";
  no marks then (the packing reports the failure).
- LOW - recorded: a daylight-saving / time-zone change between F4 and update with a changed archive
  can mark a member needlessly (the ZIP plug-in converts DOS times with the current offset); an
  archive rewritten with the same size and time is not listed again (FAT 2 s, `7z -stl`); a
  changed archive is listed twice on the refresh path (once here, once by the reopen);
  `GetFiles(ZIPRoot)` finds folders by the code-page fold (pre-existing, the panel's lookup).
- Confirmed correct: list indexes follow `List`; the re-shown dialog after a failed pack keeps the
  first marks; an item tracked already keeps the stamp of its first F4; `%` in a name is an
  argument, not the format; the eight translations keep `%s` and the formal register.

## Probe findings on the way

- The first fixture wrote every member with one fixed time - "x changed" had the same size and
  time as before and could not be told apart: the member time now follows the tag, and the row
  `x-same-stamp` records the limit (plain).
- The ZIP plug-in's "multi-volume or corrupted - insert the last disk, OK when ready" box loops on
  OK; the probe answers Cancel (a person's answer).

## After

- `probe/result.txt`: the fix; `probe/result_pre153.txt`: the build before.
- Regression: 112 `diskcache_edit_probe` 14/0, 096 `archedit_probe` 17 of 17 UPDATED
  (`probe/regress_*.txt`).
- Owed to a person: the dialog with a marked line on screen (readable, scrolls), in English and
  one translated language.
