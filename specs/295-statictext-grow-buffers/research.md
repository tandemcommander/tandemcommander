# Research - 295-statictext-grow-buffers

## R1 A variant of the 293 rule, or storing each result by hand?

- Decision: a variadic `SalGrowBuffers(allocated, needed, SalGrowBuf(p, extra)...)` in
  `src/common/salgrowpair.h`, with the allocator-injected form `SalGrowBuffersWith(reallocFn, freeFn, ...)` for `saltests`;
  `SalGrowBufferPair` is rewritten as its two-buffer case.
- Rationale: the five buffers of `CStaticText` differ in element type (`char`, `WCHAR`, `int`) and
  size (`Text2` / `Text2W` hold three more elements for "..."), so the pair does not fit (item
  Notes). A by-hand version in `SetText` could not be tested without the GUI; the variadic rule is
  tested once with the fake heap and serves both callers. Rewriting the pair on top of it keeps one
  implementation; feature 293's test (same call order, same results) proves the pair unchanged.
- Alternatives: by hand in `SetText` (untestable, a second copy of the rule); a runtime array of
  `void**` (type punning `char**` to `void**`, loses the element type).

## R2 Attempt all growths after a failure, or stop at the first?

- Decision: attempt all, in the order given (as the pair does).
- Rationale: identical to 293's rule (the pair must keep its call sequence); each growth that
  succeeds is kept and reused by the next long text, so no work is lost. Correctness does not depend
  on it - every pointer is valid either way.

## R3 Fresh buffers and the capacity

- Decision: as in 293 - a buffer that was NULL and got a block in a failed growth is released and
  stays NULL; `allocated` changes only when all grew, so it never exceeds any buffer's real size
  (each holds `allocated + extra` elements).
- Rationale: in `CStaticText` a non-NULL `Text` without a terminator would be read by
  `strcmp(Text, text)` at the top of the next `SetText` and by `PrepareForPaint`; a fresh control
  must stay as it was (no text). All five buffers are NULL together (constructor) and grow together,
  so a fresh control has all NULL.

## R4 Sizes stay exactly as before

- `Text`: `l + ST_ALLOC_GRANULARITY` bytes; `TextW`: as many WCHARs; `AlpDX`: as many ints;
  `Text2`: `+ 3` bytes; `Text2W`: `+ 3` WCHARs - `SalGrowBuf(Text2, 3)` / `SalGrowBuf(Text2W, 3)`
  with `needed = l + ST_ALLOC_GRANULARITY` give the same byte counts. `Allocated` ends at the same
  value. The set of buffers depends on `Flags`, which are fixed in the constructor.
- The old order of calls (Text, TextW, AlpDX, Text2, Text2W) is kept.

## R5 `CStatusWindow::SetSize`

- Decision: `Size = (char*)malloc(30); if (Size != NULL) Size[0] = 0;` (the existing
  `if (Size != NULL)` block below already guards the rest), plus `TRACE_E(LOW_MEMORY)` as the core
  does for failed allocations.
- Readers of `Size`: the layout (`if (Size != NULL)` before measuring - `SizeRect` stays empty
  otherwise), the paint (only inside `SizeRect.left < SizeRect.right`), the destructor (`if (Size !=
  NULL)`). Without storage no size is shown; the next `SetSize` tries again.

## R6 Consumers of `CStaticText::SetText`

- Core dialogs (dialogs*.cpp, zip.cpp, logo.cpp, plugins3.cpp) and plug-ins through
  `CGUIStaticTextAbstract::SetText`; all get TRUE / FALSE as before. On FALSE the old text stays
  shown (as the old code intended); no caller changes.
