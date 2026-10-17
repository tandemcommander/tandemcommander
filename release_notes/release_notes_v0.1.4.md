# Tandem Commander 0.1.4

**Released 19 August 2026 · build 188 · Windows 11 or newer, 64-bit · bug-fix release**

## Fixed

- Thumbnails view (Alt+5) shows previews right away, even in folders with thousands of large photos — the files currently on screen are always generated first.
- Scrolling or jumping anywhere in a large folder immediately switches preview generation to the files you are looking at, and the application stays responsive while previews load.
- Photos taken in portrait orientation are shown correctly rotated in Thumbnails view.
- The DEL key moves files to the Recycle Bin as configured — in every folder, including those with accented characters in the path, where it silently deleted permanently before.
- Folders synced by OneDrive can be deleted without the confusing "error deleting directory link" message.
- Copying file names and file lists to the clipboard (Ctrl+M, Ctrl+C, Copy UNC path, copies from the Find window and the viewer) keeps accented characters intact instead of producing garbled text.
- Saving a file list (Ctrl+M) works with accented file names and in Windows profiles whose TEMP folder contains accented characters.
- File-list columns produced with width modifiers line up correctly for names with accented characters.
- TortoiseGit/TortoiseSVN status badges appear again when display scaling is set to anything other than 100 %.
- Status badges refresh automatically in folders with accented characters in the path.
- The "sync in progress" badge from 0.1.3 keeps working on machines with many badge providers installed.
- Hint tooltips and dialog labels display correctly in translated user interfaces — no more garbled or cut-off text (for example the Czech "Soubor:" label).
- Settings migrated from Altap Salamander no longer start with icon badges switched off.

## Upgrading

- Install over the previous version — settings are preserved, plugins built for 0.1.0–0.1.3 keep working (plugin interface unchanged at 106).

---

Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full technical detail in `CHANGELOG.md`
