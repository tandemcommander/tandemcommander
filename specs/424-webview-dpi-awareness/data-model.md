# Data model - 424-webview-dpi-awareness

No stored data changes. The entities involved:

- **Requested viewer rectangle**: `left, top, width, height` given to `ViewFile` by the core, in
  the program's system coordinates. It is mapped to the viewer thread's per-monitor coordinates
  through the monitor nearest to it (`SalDpiMapRect`).
  - Rule: both monitor rectangles non-empty → the linear map, rounded to the nearest pixel;
    otherwise unchanged (refuse to guess).
  - Identity when the two monitor rectangles are equal (unchanged scaling).
- **Remembered placement** (`WindowPlacement`, `REG_BINARY`, both plug-ins): format unchanged,
  written and read on the viewer thread.
- **Code Viewer status font / height**: derived from the window's current DPI. Re-derived on
  `WM_DPICHANGED`.
