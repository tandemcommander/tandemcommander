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

- `src/common/salregfind.h`: `SalRegViewTextToCodePageAlloc` + `SALREGVIEW_CONVERTED / UTF16 /
  LOWMEM`; `<limits.h>` and `<stdlib.h>` included by the header (INT_MAX, malloc).
- `src/plugins/regedt/fs3.cpp` `ExportValueData`: the value buffer is `size` bytes (no `extra`);
  after the read, for a text type with `ExportStringsForViewerInASCII`, the rule with `CP_ACP`;
  CONVERTED -> write the copy and its count; UTF16 -> write the data as stored; LOWMEM ->
  `IDS_LOWMEM`, no file. The copy is freed on every path after it exists. Write check
  `WriteFile(...) && written == size`, `written` initialised.
- `src/saltests/saltests.cpp`: `TestRegViewTextToCodePage387` (65001, 932, 1250 byte-identical
  to the old export, REG_MULTI_SZ, odd size, empty / 1 byte, invalid code page, NULL arguments,
  lone surrogate, negative control of the old space on 65001 and 932).

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format of the changed lines: no difference (the files' older differences untouched).
- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (regedt.spl and saltests.exe rebuilt).
- `saltests.exe` -> `saltests: 30714 checks, 0 failed`, exit 0.
- Negative control (mutation): the rule's count replaced by the unit count (the old sizing),
  rebuilt -> `saltests: 30714 checks, 5 failed` - the 65001 `a€`, 65001 `čččč bar`, 932,
  REG_MULTI_SZ and lone-surrogate rows; the 1250 row passes (as it must). Header restored with
  `git checkout HEAD -- src/common/salregfind.h`, rebuilt -> `0 failed`. (A first mutation run
  showed 0 failed because the exe had not been relinked yet; the touched rebuild showed the 5.)
- The measurement repeated: the ctypes table above is the old behaviour; the rule now produces
  the "needed" byte counts of that table (5 / 13 / 5) and the 1250 bytes unchanged (9).
- GUI probe: NOT DRIVEN - the machine's ANSI code page is 1250, where old and new write the same
  bytes (as 278 found for Find); F3 on a UTF-8 / DBCS machine is owed to a person (person-step
  item at closing). The call site rests on reading plus the review.
- Short write (FR-005): no automated test (cannot be driven in saltests); by reading and review.

## Found on the way (Inbox)

- `registry-editor-view-a-key-that-cannot-be-opened-is-still` (measure:387): the
  `RegOpenKeyExW` failure branch of `ExportValueData` does not return.

## Review

### Review 1 (independent, refute-first) - no MUST

Re-ran the ctypes table (same result), saltests 30714 / 0, the encoding guard; built the new
call-site code into a harness with an `activeCodePage=UTF-8` manifest (`GetACP()` = 65001): the
file held `61 E2 82 AC 00`, all 13 bytes of `čččč bar` + NUL, the whole REG_MULTI_SZ; 1250 =
old bytes. Own mutations of the rule: old sizing 5 failed, dropping the last unit 7 failed.
Callers: only `CPluginFSInterface::ViewFile`; a FALSE export drops the cache copy, no viewer.
No data-loss path (only a temporary copy is written). Confirmed the Inbox finding.

- SHOULD 1 - the call site had no automated proof (dropping `size = convertedLen` or writing
  `data` would stay green). **Done**: the whole decision (type, switch, which bytes and how many)
  is now the rule `SalRegViewExportBytes` (`salregfind.h`); `ExportValueData` only writes the
  returned pointer / length and frees the returned copy. 11 new checks (REG_SZ / EXPAND_SZ /
  MULTI_SZ converted; switch off, REG_BINARY, REG_DWORD, invalid code page, empty -> as stored,
  pointer identity; 1250 old bytes). Mutation `*writeLen = outLen` removed -> `30724 checks,
  4 failed`; restored -> `0 failed`. The reviewer's note that a UTF-8 manifest makes the GUI
  case drivable on a copy of the exe is recorded in the person-step item (not tried here; the
  product under a changed manifest is unproven).
- SHOULD 2 - the "negative control" rows in saltests only checked Windows, and
  `old[1] != '\xE2'` relied on undocumented buffer filling. **Done**: the block is labelled
  as the defect's premise (the control is the mutation run), the `old[1]` check removed.
- NOTE 1 - the `size / 2 > INT_MAX` guard can never be true. **Done**: removed (and `<limits.h>`).
  The constant `SALREGVIEW_UTF16` renamed `SALREGVIEW_ASSTORED` (it now also covers non-text
  types).
- NOTE 2 - the UTF-16 fallback has no BOM: accepted (near-unreachable with flags 0; spec
  Clarifications).
- NOTE 3 - on a single-byte code page characters outside it still become `?`: as before, out of
  scope.
- NOTE 4 - Review section / CHANGELOG pending at that point: done at closing.

After the fixes: encoding guard `TOTAL: 0 finding(s)`; `.\build.cmd` `BUILD SUCCEEDED`;
`saltests: 30724 checks, 0 failed`. (Trap met twice: the first saltests run after a header-only
change can use a not yet relinked exe - check its time stamp; a second `build.cmd` relinked it.)
