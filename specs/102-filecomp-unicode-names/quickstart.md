# Quickstart: feature 102

Automated (hidden desktop; close an installed Tandem Commander first):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -WaitSeconds 7200 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\102-filecomp-unicode-names\probe\filecomp_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: 95 PASS / 0 FAIL.

By hand (Release build, a real mouse):
1. Two files `пример1.txt` / `пример2.txt` with different content: select
   both, Ctrl+Shift+C: the comparator shows the differences; reopen the
   dialog: the history shows the names exactly.
2. Drag the two files onto the Compare Files dialog's fields and onto an
   open comparator window.
3. `voilà.txt` and `voila.txt` with different content in one folder: compare
   `voilà.txt` with another file - the comparator names `voilà.txt`.
4. From a command prompt: `fcremote.exe -w "C:\t\Petrů 1.txt" "C:\t\Petrů 2.txt"`
   with the program closed and running; the prompt returns when the
   comparator window is closed.
5. A version-control client configured to use `fcremote.exe` as its diff
   tool, with a file named in Cyrillic.
