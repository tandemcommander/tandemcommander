# Quickstart - validating feature 284

Prerequisites: Debug x64 build (`build.cmd`), no `tandemcommander.exe` running, the admin shares
`C$` and `D$` of this computer reachable as `\\localhost\C$` / `\\localhost\D$`.

1. Unit rule: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `saltests: <n> checks, 0 failed`
   (section `TestUncShareRoot284`, contract [contracts/share-root-rule.md](contracts/share-root-rule.md)).
2. Probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\284-share-root-parent\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\284-share-root-parent\probe\shareroot_probe.ps1 -Expect fixed -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: rows B1 G1 D1 O1 X1 E1 S1 S2 L1 PASS (and their END rows); registry restored and
   identical. Before the fix (`-Expect measure`, `result_before.txt`): B1 G1 X1 E1 "nothing
   happens", D1 O1 open the first folder.
3. By hand (a person, visible desktop, optional): in `\\<a file server>\<share>` press Backspace -
   the server's shares appear under the directory line; Esc - nothing changes.
