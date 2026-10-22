# Quickstart - validating 308-pax-deep-unpack

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe (hidden desktop, Python on PATH):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\308-pax-deep-unpack\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\308-pax-deep-unpack\probe\unp308_probe.ps1 -Label after -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: PASS 10, FAIL 0 (UNP-DEEP 34/34, UNP-DEEP-DEL 34/34 + archive deleted, UNP-TOOLONG-DEL
   ok.txt + "(206)" + archive kept, UNP-DEB 5/5, COPY-DEEP 32/32; END rows PASS).
4. Regression: `specs\306-tar-pax-headers\probe\pax306_probe.ps1` the same way -> 28 / 0.
