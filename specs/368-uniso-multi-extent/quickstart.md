# Quickstart - validating 368-uniso-multi-extent

Prerequisites: Debug x64 build (`.\build.cmd`), Python 3, WSL Ubuntu for the real 4 GiB image (optional; ~9 GB free
in %TEMP%).

1. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoMultiExtent_368`).
2. The real image (once): `wsl -d Ubuntu -- sh /mnt/<...>/probe/mkimg368.sh /mnt/<seed folder>` -> `big.iso`,
   `big.sha256`.
3. Probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\368-uniso-multi-extent\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\368-uniso-multi-extent\probe\iso368_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -BigSeed <seed folder> -OutFile specs\368-uniso-multi-extent\probe\rows_after.txt"
   ```

   Expected: every row PASS (U-PLAIN, U-RR, U-JOLIET, U-RRFIRST, U-DIRFLAG, U-BRKNAME, U-BRKEND, C-PLAIN, C-JOLIET,
   G-BIG and their END rows); at main 192383f1 all 10 RUN rows FAIL (`probe/result_before.txt`).
4. Regressions: `specs/338-uniso-skip-fails-unpack/probe/iso338_probe.ps1` and the 337 probe keep their results.
