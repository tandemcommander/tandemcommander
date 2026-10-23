# Quickstart - 324 undelete-unknown-volume

1. Measurement (before, the core's API facts): from the repository root, PowerShell:
   `python -I specs\324-undelete-unknown-volume\probe\measure_volume.py "$env:TEMP\tc324_fx_<n>"`
   -> `J2 Zálohy\ W=\\?\Volume{...}\ A(UTF-8)=FAIL(2)`, `J1 jsub\ W=FAIL A=FAIL`.
2. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
3. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`; the
   324 block checks the decision table, the root / cut helpers, and on a real fixture under
   `%TEMP%` (junction `Zálohy` -> the volume root, junction -> a volume-GUID subfolder, a missing
   target below each) that `SalVolumeGuardForPaths(target, root, FALSE, TRUE)` answers "same".
4. Person step (elevated program): Plugins > Undelete on a volume X mounted also under a folder
   named outside ASCII; restore into that folder -> the same-partition warning appears.
