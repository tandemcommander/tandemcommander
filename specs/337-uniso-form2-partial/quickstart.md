# Quickstart - validate 337-uniso-form2-partial

Prerequisites: WSL Ubuntu (genisoimage seeds, as 334-336), Python, the Debug build, no running
`tandemcommander.exe`.

1. `.\build.cmd` -> `BUILD SUCCEEDED`; `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`.
2. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\337-uniso-form2-partial\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\337-uniso-form2-partial\probe\iso337_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: S-VCDPART, S-VCDCOV, C-VCDCOV, M-FORM2COV, S-VCDTAIL kept; S-VCDFULL, C-VCDFULL, S-VCDGAP
   deleted; 336's other rows as before; registry restored + identical. `-FoldersOff`: MF-FORM2COV kept,
   MF-FORM2FULL deleted.
3. Real Video CDs: `specs\335-uniso-raw-track-lost\probe\review3\rev335c_probe.ps1 -ImgDir %TEMP%\rev335c\imgs`
   -> R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG deleted, R-VCD-HOLE / X-SHORT kept.
4. Negative control: `MarkUncoveredStreams` without the gap check -> the partial rows fail (deleted).
