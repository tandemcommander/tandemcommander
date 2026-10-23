# Quickstart - validating 318-pack-name-trailing-dot

Prerequisites: Debug x64 build (`.\build.cmd`), no other `tandemcommander.exe` running.

1. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> last line
   `saltests: <n> checks, 0 failed`; `TestPackName318` covers every case of spec FR-001 / FR-002
   and the near misses.
2. GUI probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\318-pack-name-trailing-dot\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\318-pack-name-trailing-dot\probe\pack318_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS - the 12 refusal rows show "The path specified is invalid." and the
   dialog again with nothing created; ` ..` stays refused; the 7 packed controls and the empty
   entry unchanged; registry restored and identical.
3. Regression: 317's probe (`specs/317-pack-name-space/probe/pack317_probe.ps1`) - 28 PASS / 0 FAIL.
4. Negative control: the same probe on the build before the change - the 12 refusal rows FAIL
   (`probe/result_before.txt`).
