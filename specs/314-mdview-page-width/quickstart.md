# Quickstart - validating 314

1. Generator: `tests\mdview_htmlgen_test\build_and_run.cmd` -> `RESULT: PASS`, the new
   page-width assertions included (Normal byte-identical article tag, one class per level, the
   CSS rules, an unknown stored value -> Normal, View Source carries the class).
2. Build: `.\build.cmd` -> `BUILD SUCCEEDED`. (`.\build.cmd full` needs the two-stage `.slt`
   refresh first - new strings.)
3. Probe (hidden desktop, PowerShell):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\314-mdview-page-width\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\314-mdview-page-width\probe\pw314_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`
   -> menu rows, choice rows, stored value, restart, unknown value: PASS; width rows PASS or
   NOT DRIVEN.
4. Regression: `specs\081-mdview-shared-webhost\probe\mdview_probe.ps1 -Scenario smoke` on the
   hidden desktop, as recorded in the fix-log.
5. Person (on a real screen): open a document with a wide table in a maximised window and choose
   each level - the column widens Normal < Wide < Wider < Full Window; in Full Window the table
   has no scroll bar; dark menus show the radio bullet; the menu texts in the eight languages after
   the `.slt` refresh.
