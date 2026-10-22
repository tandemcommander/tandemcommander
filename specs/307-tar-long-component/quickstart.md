# Quickstart - validating feature 307

Prerequisites: Debug x64 build (`build.cmd`), Python 3 (`tarfile`, `zipfile`), 7-Zip at
`C:\Program Files\7-Zip\7z.exe` (optional: the 7Z row is NOT DRIVEN without it).

1. Unit rules (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   last line `saltests: <n> checks, 0 failed` (feature 307 checks of `sallistingname.h`).
2. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\307-tar-long-component\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\307-tar-long-component\probe\tar307_probe.ps1 -Label after -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: every row PASS - GNU-TOOLONG / GNU-DEEP open with a "(206)" message and extract only
   `ok.txt`; GNU-255 and GNU-LONG extract whole; ZIP-TOOLONG and 7Z-TOOLONG do not crash; the
   registry restored identical.
3. Regression: `specs\306-tar-pax-headers\probe\pax306_probe.ps1` -> PASS 28, FAIL 0.
4. Negative controls: the GNU flag not set (tar refusal off) -> GNU-TOOLONG does not crash (the
   core refuses: "Internal error: file data structure corrupted."); the core rule's `path == NULL`
   branch off as well -> the crash returns.
