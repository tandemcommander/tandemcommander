# Quickstart - validating 336-uniso-form2-uncovered

Prerequisites: the Debug x64 build (`.\build.cmd`), WSL Ubuntu (genisoimage is fetched into
`~/tc-genisoimage` by `mkimg334.sh`), Python, Tandem Commander not running (probes share its registry key).

1. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
2. Probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\336-uniso-form2-uncovered\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\336-uniso-form2-uncovered\probe\iso336_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS - S-VCD, M-FORM2, C-VCD, C-VCDREAL, S-VCDCOV2, S-VCDZERO keep the image;
   S-VCDCOV, C-VCDCOV, M-FORM2COV extract both files and delete it; 335's other rows as before.
3. Real Video CDs (deletion controls): `specs\335-uniso-raw-track-lost\probe\review3\rev335c_probe.ps1
   -ImgDir %TEMP%\rev335c\imgs -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1` -> R-VCD-CCD,
   R-SVCD-CCD, R-VCD-NRG deleted with every file; R-VCD-HOLE, X-SHORT kept.
4. Regression probes of 322, 329, 330, 333, 334 (their own folders) -> the verdicts recorded by 335.
