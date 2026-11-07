# Quickstart - validating 409

1. Layout checker (no clipped hint row, no new CROSS):

   ```text
   python -I -X utf8 specs/166-translation-layout/probe/layout_check.py translations --list > %TEMP%\lc_after.txt
   ```
   Expect no line matching `CLIP (czech|german|french|dutch|hungarian|romanian|slovak|spanish)/salamand D\d+ #102 `;
   the `CROSS` lines are a subset of HEAD's.

2. English room check:

   ```text
   python -I -X utf8 specs/409-mask-hints-clipped/probe/hint_room_check.py
   ```
   Expect `PASS` rows for the 11 dialogs and `TOTAL: 0 failed`.

3. Pictures (PowerShell, hidden desktop, the maintainer's instance closed):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\409-mask-hints-clipped\probe\result_after_czech.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\409-mask-hints-clipped\probe\comparedirs_shot.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lang czech -Png specs\409-mask-hints-clipped\probe\comparedirs_czech_after.png"
   ```
   Same with `-Lang french` and `-Lang english`. Expect `SHOT PNG PASS` and the whole link text in the picture.

4. `slt --verify` byte-exact; `build.cmd full` succeeds.
