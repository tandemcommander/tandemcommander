# Contract: the portable package (FR-003, Q-26, Q-28)

## Name and place

`setup\output\tandemcommander-<version>-x64-portable.zip`; `<version>` = `VERSINFO_SALAMANDER_MAJOR.MINORA.MINORB` of
`src/plugins/shared/spl_vers.h` (`/tandem-release` keeps it equal to the installer's `MyAppVersion`). The new-version check of the
portable edition requires exactly this asset name on the GitHub release
([update-check-portable.md](update-check-portable.md)).

## Archive

- One top-level folder `TandemCommander-<version>-portable/`; nothing else at the root.
- Entries sorted by path (byte order of the UTF-8 name, `/` separators), files only (folders
  implied), deflate, every time stamp = the commit time of `HEAD` (two builds of one commit give the
  same file list and the same file contents — SC-005; the archive bytes may differ only by
  signatures).
- Made by `tools/portable/make_portable_zip.py <tree> [<out.zip>]` (the version read from `spl_vers.h`); it writes
  `<out.zip>.part` and renames at the end (an interrupted run leaves no finished-looking ZIP).

## Contents

| From | Rule |
|------|------|
| the portable output tree `Release_x64_portable\` | everything **except** `*.pdb`, `*.lib`, `*.exp`, `*.ilk`, `*.iobj`, `*.ipdb`, any `Intermediate\` or `obj\` folder, `utils\salext*.dll` (FR-006a), and any `settings\` folder (a build tree that was run) |
| `LICENSE` (repository root) | as `LICENSE.txt` (GPL v2) |
| `doc\third_party.txt`, `doc\license\*.txt` | as `doc\…` (the notices) |
| `src\plugins\7zip\7za\DOC\copying.txt`, `License.txt` | as `doc\license\license_lgpl21.txt`, `doc\license\7zip_license.txt` (7-Zip in `plugins\7zip` is LGPL; `third_party.txt` says a copy of the licence is included) |
| `tools\portable\README-portable.txt` | as `README-portable.txt` |

The script fails (non-zero) if `tandemcommander.exe` is missing, is not the portable edition (its
`FileDescription` must end with `(portable)`, e.g. `Tandem Commander, File Manager (portable)`), or if any excluded pattern would still be
packaged.

## README-portable.txt (English, plain text, ≤ 60 lines)

1. What it is: Tandem Commander <version>, portable edition — no installation, nothing written to
   the registry; Windows 11 x64.
2. Use: unpack the whole folder anywhere writable and run `tandemcommander.exe`. Downloaded with a
   browser: right-click the ZIP > Properties > *Unblock* before unpacking (Mark of the Web, Q-27).
3. Settings: in `settings\` next to the program; copy the folder to take everything along; the
   program can run from read-only media (changes are not saved there).
4. Update: unpack the new version next to the old one and copy `settings\` into it.
5. Remove: delete the folder. Nothing else is left on the PC (temporary files are removed when the
   program closes).
6. What is different from the installed program: no Explorer integration (dragging from archives or
   FTP to Explorer), no automatic update, the title shows `[portable]`.
7. Privacy: link to https://tandemcommander.org privacy statement / `PRIVACY.md` section.
8. Licence: GPL v2, see `LICENSE.txt` and `doc\`.
