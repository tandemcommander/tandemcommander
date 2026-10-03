# Implementation Plan: File Comparator names (feature 102)

**Branch**: `102-filecomp-unicode-names` (from `101-small-leftovers`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S1 dialog and window | Unicode subclass of the path combos (`SetWindowLongPtrW` / `CallWindowProcW`), wide history fill/clear, wide drop (`DragQueryFileW`), Unicode Browse (`GetOpenFileNameW` locally), wide message loop of the comparator thread, Unicode attach for the differences combo, texts via `SG->LoadStrW` (a plug-in-local UTF-8 loader), system error texts via `FormatMessageW`, name buffers heap `SAL_MAX_PATH_UTF8` with checked appends, `FileExists` no longer treating error 123 as "exists" |
| S2 fcremote | `GetCommandLineW` + a WCHAR argv split, `GetFullPathNameW`, `CreateProcessW`, a variable-length UTF-16 message converted with `SplWToU8Alloc` on the plug-in side, channel version "1" -> "2", `-w` no longer waits forever on a mismatch |
| S3 gates | probes (hidden desktop): fixtures, routes, decoys, fcremote; both builds; regression 093, 095-101; review; Release; records |

`winliblt`'s `EditLine` fallback is shared by all plug-ins: only an opt-in
change if needed. Pre-change build: `build\tandemcommander\Debug_x64_pre102`.
