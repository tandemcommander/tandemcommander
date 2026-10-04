# Implementation Plan: plug-in names (feature 104)

**Branch**: `104-plugin-unicode-names` (from `103-same-file-delete-guard`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | sweep of the 20 enabled plug-ins (four read-only inventories + the author's reading), a scratch program for the primitive facts, the probe run on the build before (`Debug_x64_pre104`) |
| S1 shared | `splfiledlg.h` (new, header-only: `SplGetFileNameU8`, `SplBrowseForFolderU8`, `SplShowNameTooLong[W]`); `splunicode.h` `SplShortenLongTextW` + `SplDrawWindowTextW` (path labels); winliblt `EditLine`: WTF-8, a text that does not fit refused (`TooLongRefused`, `Quiet`) instead of the code-page re-read |
| S2 Renamer | `AttachToWindowKeepKind` on the five edits, wide loops (dialog thread, drains, progress), the menu bar fed code-page characters, mask / history / manual list / filter / editor as UTF-8, `$(WinDir)`... `$(SalDir)` wide, editor Browse through `SplGetFileNameU8` |
| S3 pickers | Database Viewer *Open*; FTP save log / save text / export / import / parser test (+ the documents folder wide); ZIP change-disk Browse (x2); Undelete image Browse, temp folder (x2), restore target; PictView *Copy To* Browse; Registry Editor helper fallback |
| S4 fields | PictView *Save As* (`GetSaveFileNameW` with the hook and template; the hook reads a code-page filter copy), its messages composed in one encoding, `exif.dll` loaded wide; ZIP and CAB path labels painted wide (Unicode subclass); CAB next-volume field and Browse; Undelete fields; FTP history and Copy/Move target refuse instead of a code-page re-read; SFTP field reader; Registry Editor Find loop wide and its external editor launched like the Renamer's |
| S5 gates | saltests (pure parts), Debug + Release, guard, probe on both builds, regressions 093/094/099/102/103, records |

Disabled plug-ins: unchanged (research 3). Pre-change build: `build\tandemcommander\Debug_x64_pre104`.
