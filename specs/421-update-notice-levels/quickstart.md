# Quickstart - validating 421

## 1. Pure rules

`build.cmd` then `build\tandemcommander\Debug_x64\saltests\saltests.exe` → `0 failed`; group
`TestUpdateNotice421` covers `SalUpdDownloadInstallOffered`, `SalUpdNoticeLevelChange`,
`SalUpdSilentInstallPlanned`, `SalUpdSilentInstallDecision`.

## 2. Hidden-desktop probe

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\421-update-notice-levels\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\421-update-notice-levels\probe\notice421_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Uses 420's loopback fixture server (`specs/420-auto-update-install/probe/updserver420.py`, a signed
installer fixture of the published release) and the Debug seams. Rows:

- L level choice: shown with the stored value; changed on each form → stored; offer→notify gives the
  classic form; classic→offer downloads and shows the offer form; offer→automatic closes the window
  and the silent install starts (run log `now`); check box off disables the drop-down.
- D Download & Install: button present (installed copy, level 0), default; click → progress hint and
  *Cancel Download*; download ends → run log `now`; cancel → no run, no `.part`; a refused / no-digest
  release → no button; metered → still downloads; a verified installer present → run log at once.
- P portable copy: no Download & Install, drop-down disabled, portable hint.
- A automatic level: no notification window; run log `now` after the idle seam; with a modal dialog
  open (busy) nothing starts until it closes; a second instance → nothing starts; a launch failure
  (`TC_UPDATE_PROBE_LAUNCHFAIL`) → no second start in the session; skipped version → offer form.
- R 420 regression rows that still apply (offer form buttons, Install When I Close, exit run).

Owed to a person: real mouse / keyboard on the new controls, Narrator, the real UAC prompt and the
restart on the real desktop for both new install routes.
