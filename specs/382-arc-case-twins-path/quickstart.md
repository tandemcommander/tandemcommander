# Quickstart - validating 382-arc-case-twins-path

Prerequisites: Windows `tar.exe`, `C:\Program Files\7-Zip\7z.exe`, NTFS with per-folder case
sensitivity (fsutil), no running `tandemcommander.exe`.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestArcPathResolveCase382`).
3. Probe (PowerShell, repository root):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\382-arc-case-twins-path\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\382-arc-case-twins-path\probe\arctwins382_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   Expected: 20 / 0 (before: 14 / 6 - MIXED, MIXDEEP, MIXMISS FAIL for TAR and 7z).
4. Regressions: `specs\273-tar-case-root\probe\arccase273_probe.ps1` 12 / 0,
   `specs\252-archive-case-sensitivity\probe\arc252_probe.ps1` 16 / 0 (same runner).
5. Negative control: the new call in `ChangePathToArchive` disabled -> the probe's MIXED rows FAIL;
   the loose step of the template disabled -> saltests checks FAIL.
