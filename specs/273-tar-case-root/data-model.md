# Data model - 273-tar-case-root

## Path inside the archive (`CFilesWindowAncestor::ZIPPath`)

- UTF-8, `SAL_MAX_PATH_UTF8` bytes, no leading or trailing backslash, components separated by `\`.
- Invariant (new): after `ChangePathToArchive` succeeds, every component is spelled byte for byte
  as the folder of the archive listing it denotes (the first sub-folder the listing's own
  comparison finds equal), unless that spelling would not fit (then the typed spelling stays -
  cannot happen with the current comparisons, which preserve length).

## Listing (`CSalamanderDirectory`)

- `Dirs[i].Name` / `NameLen` - the folder's name as the plug-in added it; `SalamDirs[i]` - its
  contents (NULL = empty folder); `Flags & SALDIRFLAG_CASESENSITIVE` selects `StrCmpEx` or the
  legacy byte fold `StrICmpEx` (`SalDirStrCmpEx`).
- Unchanged by this feature.

## Rule `SalArcPathRespell` (`src/common/salarcpathspell.h`)

- Input: the listing's root, the path (optional leading / trailing backslash), an output buffer and
  its size, an accessor (count, name, sub-folder, equality).
- Output: `SAL_ARCRESPELL_OK` (output holds the re-spelled path, no leading / trailing backslash),
  `SAL_ARCRESPELL_NOTFOUND` (a component - also an empty one - names no folder), or
  `SAL_ARCRESPELL_TOOLONG` (the output buffer is too small). On anything but OK the caller keeps
  the typed path.
