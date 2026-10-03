# Quickstart: feature 098

Automated (hidden desktop; close an installed Tandem Commander first):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 7200 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\098-long-path-overruns\probe\fix_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: 107 PASS / 0 FAIL / 3 not driven / 1 informative (the F6 row of
the next backlog item).

By hand (Release build):
1. Create a folder chain about 8,000 characters deep; enter it; click a
   middle part of the path in the directory line.
2. Ctrl+C a 600-character path in Notepad, Ctrl+Shift+V in the panel: the
   "too long" message; a short accented path: the panel goes there.
3. Pack a folder with nested sub-folders from a folder whose path has 150
   accented characters into a ZIP and a 7z archive; open the archives: all
   files present.
4. Alt+F5 with *Move* on a selection containing a junction: the link warning,
   the sources stay.
