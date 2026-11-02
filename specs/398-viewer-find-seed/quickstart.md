# Quickstart - 398

1. Build: `.\build.cmd` (PowerShell) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (`TestFindSeed398`).
3. Probe (hidden desktop, registry backed up and restored):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\398-viewer-find-seed\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\398-viewer-find-seed\probe\seed398_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   Expected: all rows PASS (before: u8-word, u8-long, u8-cjk, u8-astral FAIL).
4. By hand: view a UTF-8 file with `café` (Alt+F3), select the word, Ctrl+F - the field shows
   `café`; OK finds it.
