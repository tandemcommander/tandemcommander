# Quickstart - validating 376-qs-enter-no-flash

Prerequisites: Debug x64 build (`.\build.cmd`), no running `tandemcommander.exe`. All probes run
through `tools\run_on_hidden_desktop.ps1` from PowerShell at the repository root; each backs up
and restores the product's registry key (hash compared).

## V1 - no parent picture after Enter (SC-001), LOC / BACK (SC-002), failure rows (FR-003)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\376-qs-enter-no-flash\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\376-qs-enter-no-flash\probe\qs376_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

Expected: every CTRL, FLASH, LOC, BACK, DENY, GONE and END row PASS; FLASH runs read
`FILT ..., (OTHER ...,) NEW ...` with `PARENT 0`. Before the fix FLASH failed 3 of 3
(`result_before.txt`).

## V2 - feature 244 unchanged (SC-002)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\376-qs-enter-no-flash\probe\result_qs244.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\244-quick-search-substring-filter\probe\qs244_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect new -FilterOption 1 -Label after376"
```

Expected: `FAIL 0`, the same rows as `specs/244-*/probe/result_after.txt`.

## V3 - saltests

```text
& "build\tandemcommander\Debug_x64\saltests\saltests.exe"
```

Expected: `saltests: <n> checks, 0 failed`.

## V4 - a person (not driven)

On a real desktop: quick search a folder on a slow drive or network share, press Enter - the
panel goes from the tinted search view straight to the new folder.
