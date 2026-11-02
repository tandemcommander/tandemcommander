# Quickstart - 395-cpio-solo-empty-name

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. The probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\395-cpio-solo-empty-name\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\395-cpio-solo-empty-name\probe\cpiosolo_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (16 RUN rows); the 9 data rows show a "(123)" box and keep the archive,
   the 7 controls stay silent; registry restored and identical.
4. Regression: the probes of 306, 308, 309, 310, 321 (tar and unpack), 393 and 394 with the results
   recorded in `specs/394-cpio-empty-name-link/fix-log.md`.
