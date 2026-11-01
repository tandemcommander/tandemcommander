# Quickstart - verify 373-wsl-share-list

Prerequisites: WSL with at least one distribution (`wsl -l -v`); a Debug x64 build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed` (the checks of `SalUncShareListAsksProviders`,
   `SalUncProviderListError`, `SalUncServerNotFoundErr` included).
3. Probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\373-wsl-share-list\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\373-wsl-share-list\probe\wslshares_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect fixed"
   ```

   Expected: W1-W4, C1, N1, U1 PASS (rows explained in the probe's header); registry
   restored + identical. Before the fix (`result_before.txt`): W1, W3, W4 end in error (53).
4. By hand (optional): open the Change Directory command, type `\\wsl.localhost`, Enter: the
   menu lists the distributions; pick one -> the panel shows `\\wsl.localhost\<distro>`.
