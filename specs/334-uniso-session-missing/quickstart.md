# Quickstart - validating 334-uniso-session-missing

Prerequisites: WSL Ubuntu (the probe fetches genisoimage into `~/tc-genisoimage` without root), Python,
a Debug build (`.\build.cmd`).

1. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoTrackMarks334`).
2. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\334-uniso-session-missing\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\334-uniso-session-missing\probe\iso334_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: M-OK, S-OK (controls) PASS - image deleted; M-TERM, M-PAST, S-TERM PASS - image kept
   (before the change: those three FAIL, `probe/result_before.txt`). Registry restored + identical.
3. Regressions: the probes of 322, 329, 330, 333 (`specs/<NNN>-*/probe/iso<NNN>_probe.ps1`) keep their
   results.
