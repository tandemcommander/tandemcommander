# Research - 388 renamer-subdir-links

## R1 Which behaviour: list the link, or walk links inside the selection

- **Decision**: list the link as an item, never walk it.
- **Rationale**: the item's *Notes* name it the conservative choice; the core's feature 213
  (Change Attributes / Change Case / Convert with subdirectories, `BuildScriptDir`) does exactly
  this, also for a selected junction, and still changes the link's own entry. One rule for the
  same user action ("with subdirectories") in core and plug-in.
- **Alternatives**: walk a link whose target lies inside the selected folder, never twice by
  identity - needs the destination read (fails past 780 characters, feature 197), a visited set by
  file identity, and still lists the same files under two names (the link's path and the real
  one): one rename of them renames the first and fails on the second. Rejected.

## R2 How the plug-in tells a link

- **Decision**: from the listing - `WIN32_FIND_DATAW.dwFileAttributes` has
  `FILE_ATTRIBUTE_REPARSE_POINT` and `dwReserved0` holds the reparse tag (documented for
  `FindFirstFileW` / `FindNextFileW`). A link = a name-surrogate tag (junction / mount point
  `0xA0000003`, symbolic link `0xA000000C`, WSL `0xA000001D`, any other surrogate) or a tag that is
  0 / not known (fail closed). A readable non-surrogate tag (cloud `0x9000001A` and variants,
  OneDrive `0x80000021`, dedup `0x80000013`, WOF `0x80000017`) is a plain folder - walked.
- **Rationale**: the same decision as the core's `SalDeleteAsDirLinkDecision` (197, fail closed)
  without the destination read; the destination read can only turn an entry INTO a link, so
  leaving it out never walks a link the core would not. No extra system call per entry.
- **Alternatives**: `DeleteAsDirLink` - core only, not in the plug-in interface (adding it would
  change the ABI, maintainer-owned). Reading the tag with `GetFileInformationByHandleEx` per entry
  - an extra open per directory; the listing already has it.

## R3 The selected item

- **Decision**: a selected (or focused) panel folder whose panel attributes carry the reparse bit
  is looked up once (`FindFirstFileW` on its own full name - returns its own entry with the tag);
  when the look-up fails it is a link (fail closed). Without the reparse bit: walked as before.
- **Rationale**: `CFileData` has the attributes but not the tag. The conservative answer keeps a
  plain folder's path (and its read errors) untouched.

## R4 The count line

- **Decision**: the folders count is taken from the listed items (`IsDir`) after the listing, so
  the links `LoadSubdir` adds are counted as folders.
- **Rationale**: `dirs` was counted only in `ReloadSourceFiles`'s own branch.

## R5 Measured before

`probe/ren_link_probe.ps1` at `c6fa9cd9` (Debug x64, hidden desktop): `out`, `loop`, `selected`,
`symlink`, `mask` FAIL, `rename` FAIL (listing wrong, not renamed), `plain` PASS - see
`fix-log.md`.
