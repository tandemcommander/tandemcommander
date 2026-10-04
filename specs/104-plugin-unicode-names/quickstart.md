# Quickstart: feature 104

Automated (hidden desktop; close an installed Tandem Commander first):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3000 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\104-plugin-unicode-names\probe\plugnames_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected with `-OldExe build\tandemcommander\Debug_x64_pre104\tandemcommander.exe`: 50 PASS /
0 FAIL / 6 NOT DRIVEN (+ 1 INFO, the Save As finding); without it 47 PASS + LEGACY NOT DRIVEN. Needs a python
on PATH (or `-Python`) for the FTP log server of the `ftp-b1` rows.
On the build before: `-Exe build\tandemcommander\Debug_x64_pre104\tandemcommander.exe -Expect before`.

By hand (Release build, a real keyboard and mouse; a Czech or other non-Russian Windows):
1. Renamer (Ctrl+Shift+R) on one file: type `Отчёт.txt` as the new name with a Russian
   keyboard layout; Rename. Then `voilà.txt` with an existing `voila.txt` beside it: no
   "overwrite?" question, `voila.txt` untouched.
2. Renamer: mask `Ж*.txt`, the preview lists only the matching file; manual mode shows accented
   and Chinese names exactly; *Edit* (external editor) and *Filter* keep them.
3. FTP: Logs window - *Save Log* to `C:\Users\<an accented name>\Documents\ftp.log`; Configuration -
   Servers - *Export* to a Cyrillic file name, *Import* it back.
4. ZIP: open a multi-volume ZIP from a USB stick, Browse for a volume named in Cyrillic.
5. Undelete: *Restore encrypted files* into a folder named `voilà` (a `voila` folder beside it).
6. Registry Editor Find: type Cyrillic text into the search field.
7. Install into a folder named outside the code page (per-user, under such a user name): PictView
   shows EXIF information (exif.dll loads); the Renamer's `$(SalDir)` expands correctly.
