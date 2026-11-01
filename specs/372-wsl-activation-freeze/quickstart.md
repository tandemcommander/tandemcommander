# Quickstart - validating 372

Prerequisites: a WSL distribution named `Ubuntu` (or pass `-Distro`), `build.cmd` done.

1. Unit rule: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
   (`TestBkgndPathCheck372`).
2. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\372-wsl-activation-freeze\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\372-wsl-activation-freeze\probe\act372_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: LOCAL / WSLROOT / WSLBIG ACTIVATE PASS (no wait > 50 ms after the first 100 ms; the
   WSL rows' longest wait within the LOCAL row's + 20 ms), WSLNEW PASS (a folder created while
   inactive is entered after the activation), WSLDEL PASS (a deleted folder is left within 3 s);
   registry restored, identical.
3. Negative control: the same probe on the build of `main` (`result_before.txt`): WSLROOT /
   WSLBIG FAIL with ~400 ms waits starting at +218 ms.
4. By a person: switch with Alt+Tab to and from the program with `\\wsl.localhost\Ubuntu` in a
   panel - no busy cursor, no pause; after `wsl --shutdown` the first switch back does not freeze.
