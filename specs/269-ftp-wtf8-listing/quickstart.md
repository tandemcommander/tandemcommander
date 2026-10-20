# Quickstart - 269-ftp-wtf8-listing

Prerequisites: Python on PATH; no running `tandemcommander.exe`; the Debug x64 build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> last line
   `saltests: <n> checks, 0 failed` (the `TestFtpListingField269` checks included).
3. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`;
   `python tools/check_encoding.py --plugins` no longer lists `plugins/ftp/ftputils.cpp`.
4. Probe (PowerShell, from the repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\269-ftp-wtf8-listing\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\269-ftp-wtf8-listing\probe\ftp269_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: DL, UP-NEW, UP-ASK, DL-ACC, LEG-DL all PASS; registry restored and identical.
5. Regression: feature 224's probe (`specs\224-ftp-utf8-server-names\probe\ftp224_probe.ps1`) ->
   16 / 0.
