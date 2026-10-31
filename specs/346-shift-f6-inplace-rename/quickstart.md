# Quickstart - validate 346

1. Build: `.\build.cmd full` → `BUILD SUCCEEDED`.
2. Unit rule: `build\tandemcommander\Debug_x64\saltests\saltests.exe` → `0 failed`
   (the `salrenamekey` checks included).
3. Probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\346-shift-f6-inplace-rename\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\346-shift-f6-inplace-rename\probe\rip346_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (S6-UPDIR, S6-FILE, S6-ESC, S6-ENTER, S6-FOCUS, S6-DIR, S6-UTF8, CS6,
   KEEPS, MENU, F2, ARCHIVE), registry restored identical.
4. By hand (person step): real Shift+F6 on a real keyboard; a plug-in FS (FTP/SFTP) panel; the
   Files menu shows *Rename in Place  Shift+F6*; the help pages list Shift+F6.
