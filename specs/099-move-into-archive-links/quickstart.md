# Quickstart: feature 099

Automated (hidden desktop; close an installed Tandem Commander first):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\099-move-into-archive-links\probe\linkmove_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: 24 PASS / 0 FAIL.

By hand (Release build, a real mouse):
1. `mklink /J C:\t\B\J C:\t\X` with a file in `C:\t\X`; open a ZIP
   archive in the other panel; drag `B` onto it with Shift (Move): the link
   warning, nothing happens; `C:\t\X` keeps its file.
2. The same with Ctrl+X on `B` and Ctrl+V in the archive panel.
3. With an FTP server: F6 of `B` to the server: `X` keeps its file, the
   server gets `B` with an empty `J`.
