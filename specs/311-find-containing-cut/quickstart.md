# Quickstart - validating 311

Prerequisites: `build.cmd` (Debug x64) succeeded; no other tandemcommander.exe running.

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\311-find-containing-cut\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\311-find-containing-cut\probe\grep311_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

Expected: every row PASS (grep, grep-ctl, grep-regex, grep-hex, grep-add, grep-manage, grep-ignore,
grep-option, view-find, view-ctl, view-copy), the registry restored and identical, the fixture
removed. Before the change the refusal rows FAIL (measured 8 FAIL at 95145b44).

Regression: 291's probe (`specs\291-masks-cut-rest\probe\mask291_probe.ps1`) all PASS.

By hand (a person, real keyboard): Find, Search file content, type 67 CJK letters into Containing,
Enter -> "The path specified is too long.", the text stays whole.
