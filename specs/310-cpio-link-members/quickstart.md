# Quickstart - validating feature 310

Prerequisites: Python 3 on PATH; no `tandemcommander.exe` running; Debug x64 build.

```powershell
.\build.cmd                                                          # BUILD SUCCEEDED
& "build\tandemcommander\Debug_x64\saltests\saltests.exe"            # saltests: <n> checks, 0 failed
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\310-cpio-link-members\probe\result_after_run.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\310-cpio-link-members\probe\cpio310_probe.ps1 -Label after -OutFile specs\310-cpio-link-members\probe\result_after.txt -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: every row PASS (before the fix: 13 PASS / 7 FAIL, `probe/result_before.txt`); the registry
restored and identical. Regressions: the probes of features 309, 308 and 306 unchanged
(`specs/309-tar-link-members/probe/link309_probe.ps1` 16 / 0, ...).

Rows (see the probe header): CPIO-HARD-DEL, CPIO-CRC-HARD-DEL, CPIO-HARD-FIRST-DEL,
CPIO-HARD-EMPTY-DEL, CPIO-HARD-DEV-DEL, CPIO-ODC-HARD-DEL, CPIO-SYM-DEL, CPIO-FIFO-DEL, COPY-CPIO-ALL,
COPY-CPIO-ONE, VIEW-CPIO-ONE (F3 of a name stored with size 0 - the cached copy holds the data),
VIEW-CPIO-FIRST (F3 of the later name in the data-first layout - a box, no empty copy).
