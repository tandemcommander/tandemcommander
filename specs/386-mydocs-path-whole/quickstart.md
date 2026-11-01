# Quickstart - 386-mydocs-path-whole

1. Build Debug x64: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Rule checks: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (`TestDocumentsPath386`).
3. GUI probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\386-mydocs-path-whole\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\386-mydocs-path-whole\probe\mydocs386_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   The Documents folder is named by the Debug seam `TC_PROBE_MYDOCS_FILE` (a UTF-8 file).
   Rows: `SHORT` (control), `LONG` (Documents = `%TEMP%\tc386\<90 CJK>`, its 259-byte prefix
   folder exists too; the drive bar Documents button; PASS = the whole folder), `LONG200` (200
   letters, 640 bytes; PASS = the whole folder), `RESCUE-SHORT` / `RESCUE-LONG` (the left panel
   on a subst drive whose folder then denies listing, refresh; the rescue path "Documents";
   PASS = the short folder / not the prefix folder). Before the fix `LONG` and `RESCUE-LONG` give
   the prefix folder and `LONG200` the Desktop (3 FAIL); after the fix all PASS
   (`RESCUE-LONG` = the drive root: the rescue path holds `MAX_PATH` bytes).
