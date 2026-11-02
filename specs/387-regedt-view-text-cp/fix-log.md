# Fix log - 387-regedt-view-text-cp

Backlog item `registry-editor-view-of-a-text-value-cut-text-and-a-stray` (source review:278).

## Measurement before (main at 477f01b1)

- Site: `src/plugins/regedt/fs3.cpp`, `ExportValueData`: `extra = size / 2`,
  `malloc(size + extra)`, `WStrToStr((char*)data + size, size / 2, (LPWSTR)data, size / 2)`,
  `size /= 2`, `WriteFile(file, translated, size, ...)`. `WStrToStr` (`regedt/utils.h`) =
  `WideCharToMultiByte(CP_ACP, 0, ...)`, on failure a NUL into the last byte of the space.
- Reachable: F3 on any text value -> `CPluginFSInterface::ViewFile` -> `ExportValueData`;
  `ExportStringsForViewerInASCII = TRUE` (fs3.cpp:6), no setting changes it. Only caller.
- Reproduction (python ctypes `WideCharToMultiByte` with the old sizing, space = units; script
  `%TEMP%\claude\repro_regview.py`, run `python -I`; machine ACP 1250):

  | code page | text (with NUL) | old ret | old bytes | needed |
  |---|---|---|---|---|
  | 65001 | `a€\0` | 0 | `61 AA 00` (stale 0xAA) | 5 |
  | 65001 | `čččč bar\0` | 0 | `C4 8D x4 00` (` bar` lost) | 13 |
  | 932 | two hiragana + NUL | 0 | `82 A0 00` (cut) | 5 |
  | 1250 | `čččč bar\0` | 9 | whole | 9 |

- The GUI case needs a machine whose ANSI code page is UTF-8 or DBCS: not reachable here.
- Also in the same write: `BOOL b = WriteFile(...) || written != size;` - a short write (or a
  failed write with `written != size`) counted as success.

## Decisions

- Rule `SalRegViewTextToCodePageAlloc` in `src/common/salregfind.h` (header-only, beside 278's
  `SalRegFindTextToCodePage`, which it reuses): count, allocate exactly, convert whole.
- Conversion impossible -> the UTF-16 data as stored (spec Clarifications, conservative);
  low memory -> `IDS_LOWMEM` as before; nothing to convert (< 2 bytes) -> data as stored (old
  behaviour: `extra == 0`).
- The type is taken from the read call (the old code decided from the size query - a value
  changed between the two calls could be converted by the old type; harmless improvement).
- Write check `WriteFile(...) && written == size` (spec FR-005).
- speckit-analyze: 0 CRITICAL / 0 HIGH; C1 (MEDIUM) the short-write check has no automated test -
  accepted, proved by reading and the review; C2 (LOW) the GUI case owed to a person.

## Implementation

## Checks

## Review
