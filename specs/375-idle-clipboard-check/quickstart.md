# Quickstart - validating 375-idle-clipboard-check

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
   (`TestClipCheck375`).
3. Probe (hidden desktop; holds the clipboard open ~15 s during row HELD, content unchanged):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\375-idle-clipboard-check\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\375-idle-clipboard-check\probe\act375_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: FREE and HELD PASS (longest wait < 30 ms per activation); before the change HELD
   failed with 140-142 ms (`probe/result_before.txt`). Registry restored and identical.
4. Person (real desktop): copy files in Explorer, switch to the program: *Edit > Paste* enabled;
   with a program holding the clipboard (`probe/clip_hold.ps1 -MaxSeconds 3`) switch back, wait
   until it ends, open *Edit*: *Paste* reflects the clipboard.
