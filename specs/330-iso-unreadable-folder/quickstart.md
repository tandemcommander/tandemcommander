# Quickstart - 330-iso-unreadable-folder

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Seed images (WSL Ubuntu with 328's genisoimage under `~/tc-genisoimage`) and the crafted ones are
   made by the probe itself (`probe/mkimg330.sh`, `probe/img330.py`).
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\330-iso-unreadable-folder\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\330-iso-unreadable-folder\probe\iso330_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: the damaged rows (RD-EXT, RD-REC, UD-EXT, XD-EXT) - the box "Error reading directory
   structure", `top.txt` extracted, the image KEPT; the control rows (RD-OK, UD-OK, XD-OK) - every file
   extracted, no box, the image deleted. Before the fix the damaged rows fail (image deleted).
4. Regression: `specs\328-uniso-refused-entry\probe\iso328_probe.ps1` 20 / 0 and
   `specs\329-uniso-other-readers-refused\probe\iso329_probe.ps1` all PASS.
