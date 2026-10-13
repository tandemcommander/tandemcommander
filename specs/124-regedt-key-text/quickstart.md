# Quickstart: validating feature 124

Prerequisites: no `tandemcommander.exe` running; a `build.cmd full` Debug tree (language
modules are only produced by a full build).

```powershell
# 1. build
cmd /c "E:\Projects\tandemcommander\build.cmd full"

# 2. static check: every translation of "KEY" fits whole
python specs\124-regedt-key-text\probe\check_key_lengths.py

# 3. the probe on the fixed build (hidden desktop; about 6 minutes for nine languages)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -Log $env:TEMP\tc124.log -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\124-regedt-key-text\probe\regkey_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile E:\Projects\tandemcommander\specs\124-regedt-key-text\probe\regkey_result.txt -ShotDir E:\Projects\tandemcommander\specs\124-regedt-key-text\probe\shots"

# 4. the control: the same probe with -Expect before on build\tandemcommander\Debug_x64_v019
```

Expected: step 3 ends with `FAIL 0`; rows `<lang> INFO` and `<lang> FIND` PASS in all nine
languages; the `SEL` rows show readable text (look at `probe/shots/fixed_<lang>_sel.png`).
Step 4 fails `INFO` for czech, german and slovak.

By hand (a person, visible desktop): Czech language, `reg:\HKEY_CURRENT_USER\Software`, focus a
key - the information line reads `<name>: KLÍČ, ...`; press Insert - `1 vybraný klíč`.
