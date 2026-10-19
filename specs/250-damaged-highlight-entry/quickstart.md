# Quickstart - validating 250-damaged-highlight-entry

Prerequisites: a Debug x64 build (`.\build.cmd`), an existing Tandem Commander configuration, no
running `tandemcommander.exe`.

Run on the hidden desktop (PowerShell, repository root):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\250-damaged-highlight-entry\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\250-damaged-highlight-entry\probe\hlt250_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

Expected: `Rows: PASS 18, FAIL 0` (six rows x START / END / SAVED), the registry restored and identical.
The rows and their pass conditions are in the probe header. Before the fix: CONTROL passes, the five
damaged rows fail at START (no main window).
