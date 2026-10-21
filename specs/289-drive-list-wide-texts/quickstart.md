# Quickstart - validating 289-drive-list-wide-texts

Prerequisites: Debug x64 build (`.\build.cmd`), no running `tandemcommander.exe`.

1. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> last line
   `saltests: <n> checks, 0 failed` (includes the `saldrivetext.h` checks).
2. Probe on the hidden desktop (PowerShell tool):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\289-drive-list-wide-texts\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\289-drive-list-wide-texts\probe\run289.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\289-drive-list-wide-texts\probe\results_after.txt"
   ```

   For each language module (English, Czech) the probe starts the program with the seam on,
   opens and closes the Change Drive menu, shows drive bar 2, and checks:
   - `TYPES`: valid UTF-8; `folder` equals `SHGetFileInfoW(SHGFI_TYPENAME)` of the system
     directory; `updir` equals the language's "Upper Directory";
   - every `ITEM` and `TIP` line is valid UTF-8; the unlabelled-drive item / tooltip carries the
     language's "Local Drive"; the Documents and Network items carry their words.
   Expected after the fix: all rows PASS; on the build before the fix the Czech rows and the
   `TYPES folder` row FAIL (cp1250 bytes) - the negative control.
3. Person step (no such hardware here): a CD / USB drive labelled in Cyrillic or Greek, or a
   display language outside the system code page -> the Change Drive menu, drive bar tooltip
   and the *Type* column show the real text.
