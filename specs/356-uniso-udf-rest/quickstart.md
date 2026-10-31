# Quickstart - 356-uniso-udf-rest

1. Build: `.\build.cmd` → `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (`TestIsoUdfRest_356`).
3. Measure images (optional): `python specs/356-uniso-udf-rest/probe/udfmeasure.py <images>`.
4. GUI probe (hidden desktop; no Tandem Commander may run):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\356-uniso-udf-rest\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\356-uniso-udf-rest\probe\iso356_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS - R rows keep the image (R-TWO, R-TWOIMG, R-TWOABS deleted before), C rows
   delete it. Needs IMAPI2FS (Windows) and WSL Ubuntu (mkudffs rows).
5. Regressions: `specs/354-uniso-cooked-sessions/probe/iso354_probe.ps1` 28 / 0,
   `specs/355-uniso-raw-sessions/probe/iso355_probe.ps1` 40 / 0.
