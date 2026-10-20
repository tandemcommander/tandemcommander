# Quickstart - 273-tar-case-root

Prerequisites: Windows tar.exe (`%SystemRoot%\System32\tar.exe`), 7-Zip in
`C:\Program Files\7-Zip`, `fsutil` (case-sensitive fixture folders), the Debug x64 build.

1. Build and unit rules (PowerShell, repository root):

   ```text
   .\build.cmd                                                   -> BUILD SUCCEEDED
   & "build\tandemcommander\Debug_x64\saltests\saltests.exe"    -> saltests: <n> checks, 0 failed
   ```

2. Probe on the hidden desktop:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\273-tar-case-root\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\273-tar-case-root\probe\arccase273_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: TAR-COPY / TAR-DEEP / 7Z-COPY / 7Z-DEEP - panel path in the archive's spelling
   (`\Docs`, `\Docs\Sub`) and the file extracted with its content; TAR-TWINS / 7Z-TWINS - panel in
   `\DOCS`, only `g.txt`. Rows: PASS 12, FAIL 0; registry restored and identical.

3. Regression: 252's probe `specs\252-archive-case-sensitivity\probe\arc252_probe.ps1` -> 16 / 0.

4. By hand (optional): open `<a.tar>\DOCS` in Change Directory (Shift+F7) for an archive holding
   `Docs` - the directory line shows `...\a.tar\Docs`; F5 of its files extracts them.
