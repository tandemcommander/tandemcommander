# Quickstart - 335-uniso-raw-track-lost

Prerequisites: WSL Ubuntu (genisoimage fetched by 334's `mkimg334.sh`), Python, the Debug build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoSectorForm2_335`).
3. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\335-uniso-raw-track-lost\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\335-uniso-raw-track-lost\probe\iso335_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 14, FAIL 0` - M-NOFS, M-NOFS-F1, S-NOFS, S-RAW keep the image; M-OK-2336,
   M-FORM2, S-VCD delete it; registry restored and identical.
4. Regressions: probes 322, 329, 330, 333, 334 as their features ran them; 334's S-RAW now FAILs by
   design (the image kept - spec *Clarifications*), every other row as before.
