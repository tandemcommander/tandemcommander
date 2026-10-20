# Quickstart - validating 257

1. Build: PowerShell `.\build.cmd` → `BUILD SUCCEEDED`.
2. Pure rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (the 257 checks: hex pattern bytes under code pages 65001 / 932 / 1250, strict and lenient
   grammar, count mode, too long; the whole-word rule on a later line).
3. GUI (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\257-regedt-find-words-hex\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\257-regedt-find-words-hex\probe\find_words_hex_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: 9 PASS / 0 FAIL (before: 7 / 2 - WW-LINE2, EMPTY-RX-WW), the registry restored
   identical. The HEX rows are controls with code page 1250; on a machine whose code page is
   UTF-8 (65001) they show the 2-byte case.
4. Encoding guard: `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
