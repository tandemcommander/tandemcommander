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
