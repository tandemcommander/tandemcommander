# Quickstart - validating 384-ftp-joined-column

Prerequisites: Python 3 on PATH, the Debug x64 build (`.\build.cmd`), no running tandemcommander.exe.

1. Unit rules (PowerShell):

   ```text
   & "build\tandemcommander\Debug_x64\saltests\saltests.exe"
   ```

   Expected: last line `saltests: <n> checks, 0 failed` (includes the 384 checks).

2. The probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\384-ftp-joined-column\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\384-ftp-joined-column\probe\ftp384_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: `Rows: PASS 8, FAIL 0`; ZVM-CP-DEL server got `DELE nameč.extč`; ZVM-CP-DL local file
   `nameč.extč` with content; registry restored + identical. Before the fix: ZVM-CP-DEL and
   ZVM-CP-DL FAIL (`result_before.txt`).

3. Regression probes: `specs\288-ftp-per-server-encoding\probe\ftp288_probe.ps1` (20 / 0),
   `specs\269-ftp-wtf8-listing\probe\ftp269_probe.ps1` (14 / 0),
   `specs\224-ftp-utf8-server-names\probe\ftp224_probe.ps1` (16 / 0), each through
   `run_on_hidden_desktop.ps1` as above.
