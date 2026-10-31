# Quickstart - validating 351

Prerequisites: WSL Ubuntu (334's `mkimg334.sh` fetches genisoimage), Python, the Debug build, the
0.2.0 Release tree in `build\tandemcommander\Release_x64`. Nothing else of Tandem Commander running.

1. `saltests`: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
   (`TestIsoCcdTrackKind_351`).
2. Debug probe (PowerShell, repository root):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\351-uniso-track-defaults\probe\result_after_debug.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\351-uniso-track-defaults\probe\iso351_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after-debug"`
   -> 10 / 0.
3. Release: build `uniso.vcxproj` Release x64 with `OPENSAL_BUILD_DIR=%TEMP%\tc351-rel\`, copy the
   0.2.0 tree to `%TEMP%\tc351-reltree`, put the new `uniso.spl` in its `plugins\uniso\`, run the
   probe on that `tandemcommander.exe` with `-Repeat 3` -> 30 / 0 (before: 23 / 7 on the 0.2.0 tree).
4. Mutant (Debug, CloneCD data mapping removed): C-M1, C-M2, C-M1M1 FAIL; restore, rebuild.
5. Regressions on Debug: `specs\334-uniso-session-missing\probe\iso334_probe.ps1`,
   `specs\335-uniso-raw-track-lost\probe\iso335_probe.ps1`, `specs\350-nrg-cuex-bounds\probe\nrg350_probe.ps1`
   -> their recorded results.
