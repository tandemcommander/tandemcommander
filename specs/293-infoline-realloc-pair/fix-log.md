# Fix log - 293-infoline-realloc-pair

Backlog item `the-information-line-keeps-using-a-freed-text-when-memory` (source review:276, NOTE 6).

## Measurement at ad477c57 (main, before the feature)

By reading `src/stswnd.cpp` `CStatusWindow::SetText`:

```cpp
int l = (int)strlen(txt) + 1;
if (Allocated < l)
{
    char* newText = (char*)realloc(Text, l);
    int* newAlpDX = (int*)realloc(AlpDX, l * sizeof(int));
    if (newText == NULL || newAlpDX == NULL)
    {
        TRACE_E(LOW_MEMORY);
        return FALSE;
    }
    Text = newText;
    AlpDX = newAlpDX;
    Allocated = l;
}
```

- `realloc` that succeeds may release the old block; the returned pointer is then the only valid one.
- First succeeds (moved), second fails: `Text` keeps the released block. Next `SetText` runs
  `strcmp(Text, txt)` on it, `BuildHotTrackItems` / paint read it, the destructor frees it twice.
- First fails, second succeeds (moved): `AlpDX` keeps the released block; `BuildHotTrackItems`
  writes measurements into it (`GetTextExtentExPoint*(..., AlpDX, ...)`) - heap corruption.
- Both fail: harmless (both old blocks intact).

Reachability (default configuration): the directory line and the information line are both
`CStatusWindow`. Callers of `SetText` (grep `->SetText(` in src):
`fileswn0.cpp` (directory line, 3 sites, and the information line), `fileswn1.cpp` (directory line),
`fileswn2.cpp` `ItemFocused` (information line - every cursor move), `fileswn3.cpp` (3 sites),
`fileswnb.cpp` (2 sites), `dialogs.cpp` (a progress dialog's `Status`, not a `CStatusWindow` -
checked: different class). The growth is reached whenever a line gets a text longer than any it had
(feature 276: up to 65,535 bytes, `AlpDX` 256 KB). The failure needs real memory exhaustion between
the two calls - not reproducible on the running program (no fault injection). Proof: the unit-rule
seam below plus this reading.

Callers' handling of FALSE: they skip what follows (e.g. `SetSize`) - unchanged by this feature.

Same file (item Notes): `TextW` (SetText) and `SizeW` (SetSize) are released and replaced by one
assignment each - no stale pointer. `SetSize` writes `Size[0] = 0` right after `malloc(30)` before
its NULL check - a separate low-memory defect (Inbox). Other file: `src/gui.cpp`
`CStaticText::SetText` calls `free(newText)` on the successfully reallocated text block when a later
`realloc` fails, while `Text` still holds the old (released or same) address - a separate defect
(Inbox).

## Decisions

- Store each result at once (research R1); capacity rises only when both grew.
- A block newly obtained for a buffer that had none is released again on failure (R2): a fresh
  block is uninitialized; keeping it would leave `Text` without a terminator.
- Rule in `src/common/salgrowpair.h` with the allocator injected (R3); `SetText` passes the CRT.

## Implementation

- `src/common/salgrowpair.h` (new): `SalGrowBufferPair(a, b, allocated, needed, reallocFn, freeFn)`
  and the CRT overload (lambdas - the Debug core defines `_CRTDBG_MAP_ALLOC`, so `realloc` may be a
  macro and is not taken by address).
- `src/stswnd.cpp` `CStatusWindow::SetText`: the two `realloc` calls replaced by
  `SalGrowBufferPair(Text, AlpDX, Allocated, l)`; TRACE_E and the FALSE result kept.
- `src/saltests/saltests.cpp` `TestGrowBufferPair293`: a fake heap (fails chosen calls, moves every
  successful block, poisons and marks released blocks, counts double frees); the four outcomes from
  a pair of 10 grown to 100, a retry after each failure, no allocation when the capacity suffices,
  the fresh line failing in each of three ways, and the CRT form at 65,536 elements.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)`, exit 0 |
| build | `.\build.cmd` | `BUILD SUCCEEDED` |
| unit rules | `saltests.exe` | `saltests: 25440 checks, 0 failed`, exit 0 |
| negative control | old rule (store only when both succeed) substituted in `salgrowpair.h`, `.\build.cmd`, `saltests.exe` | `saltests: 25440 checks, 13 failed` - moved-Text case: `text != oldText`, `FakeLive293(text)`, `strcmp(text, "hello")` (twice), live count, double free; moved-AlpDX case: `alpDX != oldAlpDX`, `FakeLive293(alpDX)`, `alpDX[0] == 7`, live count, double free; fresh line: 2 x live count (the old rule leaked the fresh block). Rule restored, rebuilt: 0 failed |
| probes | - | none: the low-memory case cannot be driven on the running program (spec Assumptions) |

Reading proof after the change (grep in src/stswnd.cpp): `Text`, `AlpDX`, `Allocated` are assigned
only in the constructor (NULL / 0), freed only in the destructor, and grown only through
`SalGrowBufferPair` in `SetText`. After a failed growth `Text` still holds the previous
NUL-terminated text (a moved block carries the whole old block), `TextW` / `TextLenW` / `TextLen`
are untouched, `AlpDX` holds at least `Allocated` ints with the old measurements - paint and
`BuildHotTrackItems` read within `TextLen` / `TextLenW` <= `Allocated` - 1.

## Out of scope (Inbox)

- `a-dialog-status-text-and-the-panel-size-field-crash-when` (measure:293): `CStaticText::SetText`
  (src/gui.cpp) frees the moved text block on a later failure; `CStatusWindow::SetSize` writes
  `Size[0]` before its NULL check.
