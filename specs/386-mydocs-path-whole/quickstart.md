# Quickstart - 386-mydocs-path-whole

1. Build Debug x64: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Rule checks: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (`TestDocumentsPath386`).
3. GUI probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\386-mydocs-path-whole\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\386-mydocs-path-whole\probe\mydocs386_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Rows: `LONG` (Documents = `%TEMP%\tc386\<90 CJK>`, its 259-byte prefix folder exists too; the
   drive bar Documents button; PASS = the panel shows the whole folder), `SHORT` (control: a short
   Documents folder), `RESCUE` (left panel on a path of a drive letter that does not exist,
   rescue path = Documents; PASS = the panel is not on the prefix folder). Before the fix `LONG`
   and `RESCUE` FAIL (the prefix folder), after the fix all PASS.
