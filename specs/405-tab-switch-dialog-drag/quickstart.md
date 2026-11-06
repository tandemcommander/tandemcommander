# Quickstart - validating feature 405

Prerequisites: no Tandem Commander instance running (the probes share the registry key and refuse).

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\405-tab-switch-dialog-drag\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\405-tab-switch-dialog-drag\probe\tabs405_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: START, SEAM, RELEASED, NOBUTTON, HELD PASS; REAL-FTP NOT DRIVEN; registry restored and identical.
   Before the fix (`result_before.txt`): RELEASED, NOBUTTON FAIL (capture held after the box; the tab moved).
4. Regression: the same runner with `specs\404-panel-tabs-rounded-look\probe\tabs404_probe.ps1 ... -Only MOUSE,MENU,FALLBACK` -> every row PASS (REFUSED NOT DRIVEN).
5. Person (release checklist): with a real mouse and an FTP connection in a tab, click another tab of the
   same panel, answer the FTP question with the mouse (keep the connection), move the mouse over the strip
   -> no insert mark, the next click goes where it is clicked, no tab moves.
