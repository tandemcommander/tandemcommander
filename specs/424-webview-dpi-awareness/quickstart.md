# Quickstart - validating 424-webview-dpi-awareness

## In the run (this machine, one monitor at 100 %)

1. `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
2. `.\build.cmd` → `BUILD SUCCEEDED`.
3. `build\tandemcommander\Debug_x64\saltests\saltests.exe` → `0 failed`, `TestDpiRect424` included.
4. Probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\424-webview-dpi-awareness\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\424-webview-dpi-awareness\probe\dpi424_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Rows for each viewer (Code Viewer, Markdown Viewer):
   - `AWARE`: the viewer window and the controller window have awareness 2. The browser process has
     `--embedded-browser-webview-dpi-awareness=2` and awareness 2. The program stays at 1.
   - `GEOMETRY`: the window rectangle, the client size and the status bar height equal those of the
     same probe run on the before build (label `before`, the same configuration). The page window
     (`Chrome_WidgetWin_0`) starts at the client origin and covers the client (minus the Code
     Viewer's status bar).
   - `DPICHANGED`: a synthetic `WM_DPICHANGED` with a suggested rectangle 200 x 100 px smaller
     resizes the window to it exactly, and the page still covers the client.

   Negative control: the same probe against the HEAD build (before) fails `AWARE` for both viewers.

## Owed to a person (release checklist)

- Start the program at 100 %, change the display scaling to 150 % without signing out, then press F3
  on a text file and on a `.md` file. The page starts at the client's top-left corner, fills it, the
  text is sharp and not cut off.
- Two monitors with different scaling: open both viewers on each monitor, and move an open viewer
  across. Window size follows, the page fills the client, the status bar text fits.
