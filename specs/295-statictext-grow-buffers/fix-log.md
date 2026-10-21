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
