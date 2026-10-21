# Quickstart - feature 294

Prerequisites: Debug x64 build (`build.cmd`), no running `tandemcommander.exe`.

1. Unit rule: `build\tandemcommander\Debug_x64\saltests\saltests.exe` - last line
   `saltests: <n> checks, 0 failed` (includes `TestRegKeyIdBelow294`).
2. Probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\294-regedt-move-above-parent\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\294-regedt-move-above-parent\probe\above294_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\294-regedt-move-above-parent\probe\above294_after.txt"
   ```

   Expected: every row PASS (ABOVEMOVE, ABOVEALIAS, ABOVECOPY, ABOVEDEEP, ABOVEOK refused with the
   "into itself" message and the fixture unchanged; FLATTEN, FLATCOPY, MOVE, MOVESELF as before),
   registry restored identical. `-Lang czech` for the Czech texts.
3. Regression: `specs\292-regedt-alias-move-self\probe\alias292_probe.ps1` the same way - every row
   PASS.
4. Negative control: `-Expect before` on the build of `main` e752f9b9 - recorded 14 PASS / 10 FAIL
   (`probe/above294_before.txt`).
