# Fix log - 295-statictext-grow-buffers

Backlog item `a-dialog-status-text-and-the-panel-size-field-crash-when` (source measure:293).

## Measurement at HEAD 9aa937a1 (before the change)

By reading (the item: not reproducible without memory exhaustion between the calls):

- `src/gui.cpp` `CStaticText::SetText`: `newText = realloc(Text, ...)` succeeds (may move: the old
  `Text` block is then released); `newTextW = realloc(TextW, ...)` fails -> `free(newText); return
  FALSE;` - `Text` now points at a released block either way (the same address freed, or the old
  one released by the move). With an ellipsis style, `TextW = newTextW` is stored before `AlpDX` /
  `Text2` / `Text2W` grow; a failure there frees `newText` (and `newAlpDX`, `newText2`) while `Text`,
  `AlpDX`, `Text2` still refer to the old - possibly released - blocks. Next use: `strcmp(Text, text)`
  at the top of the next `SetText`, `PrepareForPaint` / paint, the destructor's `free(Text)` (double
  free).
- `src/stswnd.cpp` `CStatusWindow::SetSize`: `Size = (char*)malloc(30); Size[0] = 0;` before the
  `if (Size != NULL)` check - a NULL write when `malloc` fails.
- Reachability: `CStaticText::SetText` - every progress dialog's status / file-name text (copy,
  move, delete, pack) and many dialog texts, also plug-ins through `CGUIStaticTextAbstract::SetText`;
  a growth happens whenever a text longer than any before is shown. `SetSize` - the free-space field
  of a panel's directory line, first set after a path change.
- `Flags` of `CStaticText` are set only in the constructor - the set of buffers grown is fixed per
  control. All five buffers start NULL with `Allocated == 0`.
- Readers of `CStatusWindow::Size`: layout (`if (Size != NULL)` before measuring, otherwise
  `SizeRect` stays empty), paint (inside `SizeRect.left < SizeRect.right`), destructor - all NULL-safe.

`BL verify` recorded: confirmed by reading at 9aa937a1.

## Decisions

- Variadic `SalGrowBuffers` in `src/common/salgrowpair.h` (research R1); `SalGrowBufferPair` becomes
  its two-buffer case; every growth is attempted (R2); fresh blocks of a failed growth released (R3).

## Spec Kit

- clarify: 4 questions answered autonomously (item / rule / conservative), recorded in spec.md.
- analyze, first run: 0 CRITICAL, 0 HIGH, 0 MEDIUM, 2 LOW (D1 duplicate header-comment task T011,
  folded into T002; I1 the allocator-injected form unnamed in plan / research, named
  `SalGrowBuffersWith`). Second run: 0 findings.

## Implementation

- `src/common/salgrowpair.h`: `CSalGrowBuffer<T>` / `SalGrowBuf(ptr, extra)`, variadic
  `SalGrowBuffersWith(reallocFn, freeFn, allocated, needed, bufs...)` and the CRT form
  `SalGrowBuffers(allocated, needed, bufs...)` (realloc / free inside lambdas - the Debug core's
  `_CRTDBG_MAP_ALLOC` macros). Every growth is attempted in the order given (a braced initializer
  list evaluates in order), each success stored at once, `allocated` raised only when all grew, a
  fresh block of a buffer that had none released on failure. `SalGrowBufferPair` (both forms) is now
  the two-buffer case - the same calls in the same order with the same sizes (`needed * sizeof`).
- `src/gui.cpp` `CStaticText::SetText`: the five hand-written `realloc` calls replaced by
  `SalGrowBuffers(Allocated, l + ST_ALLOC_GRANULARITY, Text, TextW[, AlpDX, Text2 +3, Text2W +3])`;
  failure: `TRACE_E(LOW_MEMORY); return FALSE;` as before.
- `src/stswnd.cpp` `CStatusWindow::SetSize`: `Size[0] = 0` only when `malloc(30)` succeeded, else
  `TRACE_E(LOW_MEMORY)`.
- `src/saltests/saltests.cpp` `TestGrowBuffers295` (845 checks) on feature 293's fake heap (fails
  chosen calls, moves every grown block, poisons and marks released ones): the five-buffer set and
  the two-buffer set, every subset of the growth calls failing (31 + 3 failing subsets), the old
  contents of all forms kept, each released old block really dead, a later growth succeeds, a text
  that fits allocates nothing; a fresh set failing at each call stays all NULL with no live block;
  the CRT form with the sizes `CStaticText` asks for.

## Reading proof

`CStaticText::SetText` (T007):
- Sizes on success are the old ones: `Text` `l + 20` bytes, `TextW` `(l + 20) * sizeof(WCHAR)`,
  `AlpDX` `(l + 20) * sizeof(int)`, `Text2` `l + 20 + 3` bytes, `Text2W` `(l + 20 + 3) *
  sizeof(WCHAR)`; order Text, TextW, AlpDX, Text2, Text2W as before; `Allocated = l + 20` as before.
- Failure: every pointer refers to a live block (a grown one stored at once, a failed one untouched),
  contents kept by `realloc`, `Allocated` the old value - each block holds at least `Allocated`
  (+3) elements; `Text` / `TextW` / `AlpDX` / `Text2` / `Text2W` still hold the old text and its
  layout, so `strcmp(Text, text)` at the next call, `PrepareForPaint`, the paint and the destructor
  use live blocks. A fresh control (all NULL, `Allocated == 0`) stays all NULL - `Text == NULL` is
  handled by the `strcmp` guard and `PrepareForPaint`.
- `Flags` are fixed in the constructor, so the set of buffers never changes between calls.

`CStatusWindow::SetSize` (T009): without storage nothing is written and the `if (Size != NULL)` block
is skipped; the layout measures the size only `if (Size != NULL)` (otherwise `SizeRect` stays empty),
the paint draws only inside a non-empty `SizeRect`, the destructor checks NULL; the next `SetSize`
calls `malloc` again.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` | `BUILD SUCCEEDED` (only the pre-existing regedt C4267 warnings) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 26303 checks, 0 failed` (25,458 before; `TestGrowBufferPair293` passes on the rewritten pair) |
| negative control A | `SalDropFreshBuffer` replaced by "free every grown block" (the old `SetText`) | `26023 checks, 77 failed` (b.Live 32, live count 32, AllNull 7, the 293 pair 6) |
| negative control B | `allocated = needed` also on failure | `25996 checks, 95 failed` |
| negative control C | fresh blocks kept on failure (no `SalDropFreshBuffer`) | `26303 checks, 18 failed` |
| restore | header copied back, touched, rebuilt | `26303 checks, 0 failed` |
| clang-format | VS LLVM clang-format on the changed regions | clean (the header's lambda call reformatted) |

No GUI probe: memory exhaustion between the calls cannot be produced on the running program (the
item: "Not reproduced (needs memory exhaustion between the calls)"); the proof is the seam and the
reading proof above, as the item's Expected allows.
