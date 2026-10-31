# Quickstart - feature 362

Prerequisites: WSL Ubuntu (genisoimage fetched without root by `mkimg330.sh` / `mkimg362.sh`, mkudffs by
`mkudf356.sh`), Python, the Debug build.

1. Build: `.\build.cmd` → `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (group `TestIsoUdfFolderEntry_362`).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\362-uniso-udf-folder-no-descs\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\362-uniso-udf-folder-no-descs\probe\iso362_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (before: PASS 15, FAIL 7 - `probe/result_before.txt`); registry restored + identical.
4. Regressions: `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1` and
   `specs/361-uniso-udf-entry-bound/probe/iso361_probe.ps1` the same way → their recorded results.
