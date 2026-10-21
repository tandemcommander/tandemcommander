# Fix log - 278-regedt-find-regexp-cp

Backlog item `regedit-find-regexp-multibyte-code-page-buffer` - Registry Editor Find: regexp
misses text past the code-page length of a value.

## Measurement before (main at cffe5eca)

- Site unchanged: `src/plugins/regedt/finddlg.cpp`, `CFindThread::Test`, regexp branch:
  `len /= 2; AsciiBuffer.Reserve(len); WStrToStr(AsciiBuffer.Get(), AsciiBuffer.GetSize(), (LPWSTR)text, len); text = AsciiBuffer.Get();`
  then the line loop runs to `text + len`. `WStrToStr` (`utils.h`) is
  `WideCharToMultiByte(CP_ACP, 0, ...)` and on failure writes a NUL into the last byte.
- Callers of `Test` (all in `finddlg.cpp`): value name `Test(name, wcslen(name) * 2, TRUE, 0)`,
  value data `Test(data, size, FALSE, type)`, key name `Test(name, wcslen(name) * 2, TRUE, 0)`.
  Reached from the Find window (Find in the Registry Editor's panel) with Regular expression
  checked and Look at keys / values / data - the default dialog has all three on.
- Reproduced with the real API (Bash: `python -I -c` with ctypes `kernel32.WideCharToMultiByte`):

  | code page | units | old call (dest = 8) | bytes scanned | need | `bar` in scanned |
  |---|---|---|---|---|---|
  | 65001 | 8 | returns 0, writes `c4 8d` x4 | 8 | 12 | no |
  | 65001, larger reused buffer | 8 | returns 12 | first 8 | 12 | no |
  | 932 | 8 | 8 (`????` for č) | 8 | 8 | yes |
  | 1250 | 8 | 8 | 8 | 8 | yes |

- The GUI case is not reachable on this machine (ANSI code page 1250).

## Analyze

`speckit-analyze` (one run): 0 CRITICAL, 0 HIGH, 0 MEDIUM, 2 LOW, both accepted - C1: the call
site's guard (`len != need` -> no match) is proven through the rule's too-small-space check,
not by its own test (no GUI fault can reach it); C2: feature 257's probe drives value data only,
key and value names take the same code path (only the NUL trimming differs).

## Implementation

- `src/common/salregfind.h`: `SalRegFindTextToCodePage(text, units, codePage, out, outSize)` -
  `out == NULL` counts the code-page bytes (`WideCharToMultiByte(codePage, 0, ..., NULL, 0)`);
  with a space it converts and returns the count, or -1 when the conversion fails or the space
  is too small (never a partial result); an empty text is 0.
- `src/plugins/regedt/finddlg.cpp`, `CFindThread::Test`, regexp branch: count with `CP_ACP`
  (-1 → no match), reserve the count, convert (a different count → no match), `len` = the
  converted count. The NUL trimming of 189, the line loop and the whole-word rule of 257 are
  untouched; `WStrToStr` and its other callers unchanged. `salregfind.h` was already in the
  plug-in's `precomp.h` (257).
- `src/saltests/saltests.cpp`: `TestRegFindTextToCodePage278` - 65001 `čččč bar` = 12 bytes,
  `bar` at the end, no NUL added, exact fit, 11 and 8 (the old space) refused; the old sizing
  emulated with the real API loses `bar` both ways (failed conversion into 8 bytes; 12 converted
  into a larger space, 8 searched); 932 `ああ bar` = 8 bytes from 6 units, `bar` beyond the unit
  count; 1250 = 8 bytes as before; lone surrogate / unrepresentable letter replaced (count =
  conversion, 6 under 65001, `?a?` under 1250); only the given units; empty / NULL text 0; a bad
  code page -1. clang-format applied to the new lines only (`--lines`).

## Checks

| Check | Command | Result |
|---|---|---|
| build before | PowerShell `.\build.cmd` (tree unchanged) | `BUILD SUCCEEDED` |
| probe before | `tools\run_on_hidden_desktop.ps1` with `specs\257-regedt-find-words-hex\probe\find_words_hex_probe.ps1` → `probe/result_before.txt` | PASS 9, FAIL 0 (ACP 1250; registry restored, identical hash) |
| build after | `.\build.cmd` | `BUILD SUCCEEDED`, exit 0 (saltests.exe and regedt.spl rebuilt 04:53) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 24954 checks, 0 failed`, exit 0 |
| negative control | rule's count replaced by `units` (the old sizing), rebuilt, saltests | `24954 checks, 12 failed` (all in `TestRegFindTextToCodePage278`, 65001 / 932 / lone-surrogate / bad-code-page rows); rule restored, rebuilt, `0 failed` |
| encoding guard | Bash `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)`, exit 0 |
| probe after | the same probe → `probe/result_after.txt` | PASS 9, FAIL 0 (regexp RX-BAR / WW-LINE2 / EMPTY-RX rows drive the changed branch; registry restored, identical hash) |
| the item | the step-3 measurement as a rule check | `čččč bar` under 65001: 12 bytes searched, `bar` found (before: 8 bytes, `bar` absent) |

## Owed to a person

- NOT DRIVEN: the GUI under a multi-byte ANSI code page (this machine is 1250; the system code
  page needs a restart). Steps in `quickstart.md` step 4 - recorded as a `person-step` item at
  closing.

## Review

One independent refute-first review (general-purpose agent), no MUST findings. It re-ran the
measurement with ctypes (matches the table above), built (`BUILD SUCCEEDED`), ran saltests
(`24954 checks, 0 failed`) and the encoding guard (`TOTAL: 0`), and enumerated the callers of
`CFindThread::Test` (value name, value data, key name - all in `finddlg.cpp`) and of the new
rule (only the two calls in `Test`). Findings:

- SHOULD 1 - the same unit-sized buffer in the viewer's export (`fs3.cpp` `ExportValueData`,
  View of a text value with `ExportStringsForViewerInASCII`): outside this item → Inbox
  `registry-editor-view-of-a-text-value-cut-text-and-a-stray` (`review:278`).
- SHOULD 2 - the call-site change is not proven by an automated check: the negative control
  breaks the rule, not `finddlg.cpp`; reverting the call site would leave saltests at 0 failed
  and 257's probe at 9 / 0 (on code page 1250 the old and new code search the same bytes), so
  `result_before.txt` and `result_after.txt` are identical. **Accepted and stated plainly**: the
  probe shows only that nothing regressed on 1250; the fix of the plug-in under a multi-byte code
  page rests on the rule's checks plus reading the call site (count, reserve, convert, compare,
  `len` = count) and on the person's check - the `person-step` item created at closing.
- NOTE 3 - quickstart step 4 checked value data only → extended with a value name and a key
  name (all three callers, one restart).
- NOTE 4 - under a DBCS code page the byte-wise regexp can match a trail byte (U+30A2 = `83 41`
  under 932, so `A` matches inside it); older than this fix, UTF-8 unaffected, outside the item -
  recorded here, not added (not serious: an extra match, no data at risk).
- NOTE 5 - each text is converted twice (count, then convert): correct, slightly slower; kept
  for the plain count-first rule the item asks for.
- NOTE 6 - the new saltests checks are sound (the old-sizing control uses the real old call).
