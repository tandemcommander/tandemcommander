# Quickstart - validating 316

1. Build: `.\build.cmd` (PowerShell, repository root) - `BUILD SUCCEEDED`.
2. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\316-unpack-subdir-space\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\316-unpack-subdir-space\probe\unpack316_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS; registry restored and identical. The rows and what PASS means are in
   the probe's header (refused rows: the "Error Creating Directory" box, nothing unpacked, no
   folder without the space; space-sd-exists: files in the existing ` ssss`).
3. Negative control: the same probe against the build of `main` (b125acf7) - the leading-space rows
   FAIL.
4. Regression: 315's probe `specs\315-unpack-default-whole\probe\unpack315_probe.ps1` - 11 / 0.
5. `saltests.exe` - `0 failed`; `python tools/check_encoding.py --strict` - `TOTAL: 0 finding(s)`.
