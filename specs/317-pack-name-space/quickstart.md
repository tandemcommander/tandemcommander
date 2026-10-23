# Quickstart - validate 317-pack-name-space

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Probe on the hidden desktop (registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\317-pack-name-space\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\317-pack-name-space\probe\pack317_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS - the leading-space rows write ` report.zip`, ` notes.zip`,
   `  two.zip`, ` typed.zip`; `report.zip` next to ` report` unchanged and not asked about; the
   controls (`plain.zip`, the absolute ` abs.zip`, the empty entry refused) as before; ` ..` /
   ` .` refused ("The path specified is invalid."), nothing written. Before the fix (build of d526127f) the leading-space
   rows FAIL.
3. Regressions: 316's probe (`specs/316-unpack-subdir-space/probe/unpack316_probe.ps1`) and 241's
   probe (`specs/241-pack-long-nested-folder/probe/pack241_probe.ps1`) PASS.
4. `saltests.exe` -> `0 failed`; `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.

By hand (a person, optional): focus a folder ` report` in a disk panel, Alt+F5, OK - the panel
shows ` report.zip`.
