# Quickstart - validating 383-arc-typed-target-case

Prerequisites: `C:\Program Files\7-Zip\7z.exe` (fixtures), a Debug x64 build, no running
`tandemcommander.exe`.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (`TestArcPathApplyResolved383`).
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\383-arc-typed-target-case\probe\result_after_log.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\383-arc-typed-target-case\probe\arctarget383_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\383-arc-typed-target-case\probe\result_after.txt"
   ```

   Expected: `Rows: PASS 36, FAIL 0` (18 RUN + 18 END rows); registry restored+identical True.
   Before the fix: PASS 22, FAIL 10 (`probe/result_before.txt`).
4. Regressions: `specs\273-tar-case-root\probe\arccase273_probe.ps1` (12 / 0) and
   `specs\382-arc-case-twins-path\probe\arctwins382_probe.ps1` (24 / 0).
