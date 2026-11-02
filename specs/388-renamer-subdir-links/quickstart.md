# Quickstart - 388 renamer-subdir-links

From the repository root, PowerShell:

1. Build: `.\build.cmd` → `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (the checks `TestListedDirIsLink388`).
3. Probe (hidden desktop; creates junctions and one directory symbolic link inside
   `%TEMP%\tc388_ren`, removes them as links):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\388-renamer-subdir-links\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\388-renamer-subdir-links\probe\ren_link_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: rows `out`, `loop`, `selected`, `symlink`, `mask`, `plain`, `rename` RUN PASS, every
   END PASS, registry restored and identical, fixture removed. `symlink` is NOT DRIVEN when the
   account may not create a directory symbolic link (no Developer Mode / privilege).
4. Encoding guard: `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
