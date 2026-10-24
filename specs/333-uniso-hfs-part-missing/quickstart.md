# Quickstart - validating 333-uniso-hfs-part-missing

Prerequisites: WSL Ubuntu (the probe fetches xorriso into `~/tc-xorriso` once), Python, a Debug x64
build (`.\build.cmd`).

1. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestHfsVolumeDeclared333`).
2. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\333-uniso-hfs-part-missing\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\333-uniso-hfs-part-missing\probe\iso333_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS - H-VER / H-CAT / H-SIZE / H-EXT keep the image (ISO 9660 part
   extracted); H-OK, APM-EFI and H-NOSIG delete it as before. At e9f777da: 4 damaged rows FAIL.
3. Regressions: the probes of features 322, 329, 330 and 332 - no new FAIL row.
