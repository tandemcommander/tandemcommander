# Implementation Plan: Unicode window titles (feature 100)

**Branch**: `100-cjk-focus-name` (from `099-move-into-archive-links`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

1. Helper `SalSetWindowTitleW(HWND, const WCHAR*)` in the core (`src/common/winlib.*` next to
   `SalSetWindowTextU8`, which uses it) and a header-only copy in
   `src/plugins/shared/splunicode.h`: `SetWindowTextW` on a Unicode window,
   `DefWindowProcW(h, WM_SETTEXT, 0, text)` on a code-page window.
2. Use it at: Code Viewer (`codeview/viewer.cpp`), internal viewer (`viewer3.cpp`), Markdown
   Viewer (`mdview/viewer.cpp`), PictView (`render1.cpp`), Database Viewer (`renmain.cpp`), File
   Comparator (`mainwnd.cpp`, `worker2.cpp` - thread checked), main window (`mainwnd1.cpp`) with
   its "unchanged?" check reading `InternalGetWindowText`.
3. Probe on the hidden desktop: `probe/cjk_focus_probe.ps1` extended to every viewer and to the
   main window title; the build before as the control.
4. Independent review; gates; records; commit.
