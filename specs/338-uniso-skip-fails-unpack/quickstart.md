# Quickstart - validate 338

Prerequisites: WSL Ubuntu (genisoimage is fetched once into `~/tc-genisoimage`), Python, the Debug build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoWholeUnpack_338`).
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\338-uniso-skip-fails-unpack\probe\result_after_run.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\338-uniso-skip-fails-unpack\probe\iso338_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lib <abs path>\specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label after -OutFile specs\338-uniso-skip-fails-unpack\probe\result_after.txt"
   ```

   Expected: 8 RUN rows PASS (OK / O-YES delete the image; R-SKIP, R-SKIPALL, C-SKIP, O-SKIP, TWINS, D-SKIP keep
   it), registry restored + identical. Before the change: PASS 10 / FAIL 6 (`probe/result_before.txt`).
4. Regressions: `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1` (30 / 0) and
   `specs/337-uniso-form2-partial/probe/iso337_probe.ps1` (74 / 0) keep their results.
