# Quickstart - validating 366-uniso-form2-files

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `saltests: <n> checks, 0 failed`
   (`TestIsoXaForm2_366`).
2. Real images: vcdimager output (`vcd.bin`, `svcd.bin`, `v.mpg`, `s.mpg`) in `%TEMP%\rev335c\data` (copied
   from WSL `~/rev335c`, made by 335's reviewer 3 with ffmpeg pal-vcd / pal-svcd and vcdimager 2.0.1).
3. Images and expectations: `python -I specs\366-uniso-form2-files\probe\img366.py %TEMP%\rev335c\data %TEMP%\tc366img`
   (writes the images and `expect.json` - name, size and SHA-256 of every file each row must extract).
4. Probe on the hidden desktop:
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\366-uniso-form2-files\probe\result_after_log.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\366-uniso-form2-files\probe\iso366_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -ImgDir %TEMP%\tc366img -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label after -OutFile specs\366-uniso-form2-files\probe\result_after.txt"`
   - Expected: R-VCD-CCD / R-VCD-NRG `AVSEQ01.DAT` 690,228 bytes containing `v.mpg`, R-SVCD-CCD `AVSEQ01.MPG` =
     `s.mpg`, the image deleted; control rows (mixed attributes, no XA record, Form 1 first sector, cooked
     image) extract the 2048-byte content as before.
5. Regressions: 337's `iso337_probe.ps1` (with 336 / 335 rows), 365's `iso365_probe.ps1`, 334's probe - the
   recorded results.
