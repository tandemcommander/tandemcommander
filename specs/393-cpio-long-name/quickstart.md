# Quickstart - 393-cpio-long-name

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (no new rule; the shared decision is tested since 306 / 308 / 321).
3. Probe on the hidden desktop:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\393-cpio-long-name\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\393-cpio-long-name\probe\cpio393_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (see the probe's header for the rows), registry restored + identical.
4. Regression: the probes of 310, 321 (both), 306, 308, 309 keep their recorded results.
