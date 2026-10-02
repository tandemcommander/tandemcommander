# Quickstart: feature 095

## Automated

```
saltests.exe                                   13,102 checks, 0 failed (TestHeapString095)
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\095-archive-path-buffers\probe\longarc_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: 60 PASS, 0 FAIL (the build before the feature: 56 / 4). Close an
installed Tandem Commander first (shared registry key).

## Owed to a person

In a folder with a path of about 200 characters, a ZIP archive containing a
folder with a 200-character name and in it a file with a 150-character name:
Enter on the file opens it; F4 edits it and the archive is updated on leaving.
