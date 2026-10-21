# Quickstart: validating 288

Prerequisites: Python (for 215's `ftpmini.py`), ports 2121 and 2122 free on 127.0.0.1, system
code page 1250 (the probe's cp1250 server matches it), no running `tandemcommander.exe`.

1. `build.cmd` (Debug x64) -> `BUILD SUCCEEDED`.
2. `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `saltests: <n> checks, 0 failed`
   (includes `TestFtpServerEncoding288`).
3. The probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\288-ftp-per-server-encoding\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\288-ftp-per-server-encoding\probe\ftp288_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: LEG-MKD, LEG-REN, LEG-UP, CROSS-DEL, UTF-MKD, UNK-MKD all PASS (12 / 0 with the END
   rows); the registry restored and identical. Before the change: 8 / 4 (`result_before.txt`).
4. Regressions, same way: `specs\224-ftp-utf8-server-names\probe\ftp224_probe.ps1` (16 / 0),
   `specs\269-ftp-wtf8-listing\probe\ftp269_probe.ps1`, `specs\277-ftp-pwd-path-cut\probe\ftp277_probe.ps1`
   (their recorded results) - logs into `specs\288-ftp-per-server-encoding\probe\regress_<NNN>.txt`.
