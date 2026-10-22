# Quickstart - feature 296

Prerequisites: Debug x64 build (`build.cmd`), no running `tandemcommander.exe`.

1. Probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\296-regedt-link-target-tree\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\296-regedt-link-target-tree\probe\link296_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\296-regedt-link-target-tree\probe\link296_after.txt"
   ```

   Expected: every row PASS - LINKMOVE, LINKALIAS, LINKCOPY, LINKOK, LINKUP refused with the "into
   itself" message naming the source key and the source tree unchanged; LINKDANGLE, LINKTOP refused
   with the open-error box; LINKUPOK, LINKOTHER, MOVE as before; registry restored identical.
   `-Lang czech` for the Czech texts.
2. Regression: `specs\292-regedt-alias-move-self\probe\alias292_probe.ps1` and
   `specs\294-regedt-move-above-parent\probe\above294_probe.ps1` the same way - every row PASS.
3. `saltests` unchanged rules: last line `saltests: <n> checks, 0 failed`.
4. Negative control: `-Expect before` on the build of `main` 4420aae1 - recorded 14 PASS / 15 FAIL
   (`probe/link296_before.txt`).
