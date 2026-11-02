# Quickstart - validating 400-uniso-walk-after-unreadable

Prerequisites: WSL Ubuntu (genisoimage fetched by the seed script as in 328 / 330), Python 3.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\400-uniso-walk-after-unreadable\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\400-uniso-walk-after-unreadable\probe\iso400_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS - the damaged rows extract `top.txt` and `zlast/z.txt` of the damaged
   file system with one box and keep the image; RD-TWO / XD-TWO one box; loop rows answer within
   30 s; controls as in 330. Registry restored and identical.
4. Regressions: 328's probe (LOOP rows), 329's and 327's probes, all PASS.
