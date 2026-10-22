# Quickstart - feature 297

Prerequisites: Debug x64 build (`build.cmd`, BUILD SUCCEEDED); no `tandemcommander.exe` running.

Probe (hidden desktop, PowerShell tool, from the repository root):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\297-regedt-delete-link\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\297-regedt-delete-link\probe\link297_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\297-regedt-delete-link\probe\link297_after.txt"
```

Expected: all rows PASS (DELTREE, DELDANGLE, DELTOP, MOVETREE, MOVESKIP, MOVETOP, RENAMETOP, COPYTREE,
DEL, MOVE, DELHKCR + END rows), registry restored identical. The same with `-Lang czech`. Before the
fix (`-Expect before`): 16 PASS / 14 FAIL (`probe/link297_before.txt`).

Regression: 296's `link296_probe.ps1`, 294's `above294_probe.ps1`, 292's `alias292_probe.ps1` on the
same build - all PASS. `saltests` - 0 failed. Negative control: the link test in `DeleteKey` /
`CopyOrMoveKeyRec` disabled -> the DEL* / MOVE* link rows FAIL again.
