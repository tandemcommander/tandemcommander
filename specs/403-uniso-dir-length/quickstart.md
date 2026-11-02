# Quickstart - 403-uniso-dir-length

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoDirLength403`).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\403-uniso-dir-length\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\403-uniso-dir-length\probe\iso403_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 12, FAIL 0`; IS-NEG / IS-NEG2 / IS-MIN / IS-HUGE / IS-PAST - one read-error box,
   the other folders extracted, the image kept; IS-EDGE - everything extracted, no window, the image
   deleted. Registry restored and identical.
4. Regression probes: `specs\401-uniso-share-length\probe\iso401_probe.ps1` (10 / 0),
   `specs\400-uniso-walk-after-unreadable\probe\iso400_probe.ps1` (48 / 0), 402's `iso402_probe.ps1`
   (10 / 0), 328's probe (20 / 0).
