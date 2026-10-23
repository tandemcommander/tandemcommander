# Quickstart - validating feature 321

Prerequisites: Debug x64 build (`build.cmd`), Python 3 (`tarfile`, `zipfile`), 7-Zip at
`C:\Program Files\7-Zip\7z.exe` (optional: the 7Z row is NOT DRIVEN without it).

1. Unit rules (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   last line `saltests: <n> checks, 0 failed`.
2. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\321-tar-long-component\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\321-tar-long-component\probe\tar321_probe.ps1 -Label after -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: every row PASS - GNU-TOOLONG / GNU-DEEP / GNU-255DIR open with a "(206)" message;
   GNU-255, GNU-LONG, GNU-DIR100 whole; ZIP-TOOLONG and 7Z-TOOLONG do not crash; CPIO-778 /
   CPIO-TOOLONG with simple icons do not crash; whole-archive Unpack of the deep GNU tree writes all
   31 files (also with Delete archive after unpacking); Unpack + Delete of GNU-TOOLONG keeps the
   archive and fails; the registry restored identical.
3. Regression: `specs\306-tar-pax-headers\probe\pax306_probe.ps1` and 308's probe -> no FAIL.
4. Negative controls: the GNU flag not set (tar refusal off) -> GNU-TOOLONG does not crash (the
   core refuses); the core rule's `path == NULL` branch off as well -> the crash returns; the
   listing rule in every pass (308's `Listing` ignored for GNU) -> the deep-tree Unpack rows fail.
