# Quickstart: validating 260

1. `.\build.cmd` -> `BUILD SUCCEEDED`; `build\tandemcommander\Debug_x64\saltests\saltests.exe` ->
   `0 failed` (TestCacheTmpPath260).
2. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\260-archive-cache-long-names\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\260-archive-cache-long-names\probe\cache260_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Rows: VIEWLONG (F3 of a 90-CJK member opens the viewer), EDITLONG (F4, the copy changed, the
   archive updated: one member, whole name, new content), OVERLIMIT (a 250-letter member: the
   "resulting filename is too long" refusal, nothing extracted), CTL (short name), GZLONG (a .gz
   with a 274-byte stored name extracted under it), GZOVER (a 300-letter stored name refused,
   nothing written), GZCTL (short stored name).
3. Regression: `specs\222-name-length-units\probe\editname222_probe.ps1` (its LONG row then sees no
   refusal and an editor - still PASS by its own criterion).
4. Before / after: the same probe on the build without the change gives FAIL in VIEWLONG,
   EDITLONG, GZLONG, GZOVER.
