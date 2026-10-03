# Quickstart: feature 100

Automated (hidden desktop; close an installed Tandem Commander first):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\100-cjk-focus-name\probe\cjk_focus_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: 77 PASS / 0 FAIL.

By hand (Release build): files named with Cyrillic, Chinese and an emoji;
F3 on each (and a .md, .png, .csv); the title bar, the taskbar button and
Alt+Tab show the name exactly; the main window title in such a folder too.
