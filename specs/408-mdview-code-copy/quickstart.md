# Quickstart - validating 408-mdview-code-copy

## Automated

1. Generator and pure rules: `tests\mdview_htmlgen_test\build_and_run.cmd` -> `RESULT: PASS`
   (new rows: controls per block, source table, byte-identical document without code,
   source view without controls, `MdCodeClipboardText`, `MdParseCopyLink`).
2. Build: `.\build.cmd full` -> `BUILD SUCCEEDED`.
3. GUI probe (hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\408-mdview-code-copy\probe\result_after_run.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\408-mdview-code-copy\probe\copy408_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\408-mdview-code-copy\probe\result_after.txt"`
   -> every row PASS or NOT DRIVEN (see the probe header for the rows).

## Owed to a person (release checklist)

- Open a Markdown file with several code blocks (one Czech / emoji line, one in a
  list), hover a block: *Copy* appears top right; click: *Copied* shows bottom right and
  fades; paste into Notepad: exactly the block's code, Windows line breaks, no extra
  last line. Repeat in a dark scheme (F9) and with Tab + Enter.
