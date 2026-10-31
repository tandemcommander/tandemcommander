# Quickstart - validating 350-nrg-cuex-bounds

Prerequisites: Debug x64 build (`.\build.cmd`), Python on PATH, no running tandemcommander.exe.

1. Unit rule (PowerShell):
   `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → last line `saltests: <n> checks, 0 failed`
   (`TestNrgCuex350` among them).
2. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\350-nrg-cuex-bounds\probe\result_after_log.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\350-nrg-cuex-bounds\probe\nrg350_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\350-nrg-cuex-bounds\probe\result_after.txt"
   ```

   Expected: N-OK, N-SHORT, N-PAST, N-ODD all PASS (RUN and END rows); N-SHORT / N-PAST peak working
   set within 150 MB of N-OK's, answering within seconds; registry restored and identical.
   Before the fix (`probe/result_before.txt`): N-SHORT, N-PAST, N-ODD FAIL.
3. Regression: feature 329's probe, row A-OPEN only:
   `... -File specs\329-uniso-other-readers-refused\probe\iso329_probe.ps1 -Exe ... -Only A-OPEN` → PASS.
