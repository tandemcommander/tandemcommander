# Quickstart: feature 101

Automated (hidden desktop; close an installed Tandem Commander first):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\101-small-leftovers\probe\leftovers_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: 20 PASS / 0 FAIL / 4 NOT DRIVEN (the clipboard rows).

By hand (Release build): minimise to the tray in a folder named in Cyrillic
- the tip shows the name; copy a 600-character path in Notepad and press
Ctrl+Shift+V in a panel; Alt+F5 with *Move* on a selection with a folder you
denied yourself read access to - the new message, in Czech in the Czech UI.
