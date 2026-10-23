# Quickstart - 326-uniso-rrip-without-rr

Prerequisites: WSL Ubuntu (xorriso is fetched into `~/tc-xorriso` by the image script once).

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestSusp326`).
3. GUI probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\326-uniso-rrip-without-rr\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\326-uniso-rrip-without-rr\probe\iso326_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: RR `top.txt`, RR-DIR `folder\note.txt`, RR-LONG the 200-letter name, OLDRR `top.txt`,
   LEGACY-RR `top.txt` (by `RR`) and `FOLDER` (no `SP`), PLAIN `TOP.TXT`, J-ASCII `top.txt`; all PASS,
   registry restored and identical. Before the fix the RR, RR-DIR, RR-LONG and OLDRR rows FAIL.
4. Regression: feature 322's probe `specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1` - 18 / 0.
