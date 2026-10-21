# Research - 293-infoline-realloc-pair

## R1 Store each result at once, or allocate both before releasing either?

- Decision: store each successful `realloc` result at once; raise the capacity only when both
  succeeded.
- Rationale: `realloc` that fails leaves its block untouched; `realloc` that succeeds may have
  released the old block, so the only valid pointer after it is the returned one. Storing at once
  keeps both pointers valid in all four outcomes with no extra copy. The capacity is the smaller of
  the two real sizes (the old one) until both grew - exactly the item's Expected.
- Alternatives: `malloc` both new blocks, copy, then `free` both old ones - also correct but costs a
  copy of up to 64 KB + 256 KB per growth and changes more code.

## R2 A fresh line (no buffers yet) whose growth fails half-way

- Decision: a block newly obtained for a buffer whose pointer was NULL is released again when the
  pair fails; that pointer stays NULL.
- Rationale: a fresh block is uninitialized. Keeping it would leave `Text` non-NULL without a
  terminator while `Allocated` is 0, and the next `SetText` runs `strcmp(Text, txt)` on it - a read
  past the block. Releasing it keeps today's state (no text) exactly.
- Alternatives: write a terminator into a fresh text block - specific to the text buffer, and the
  position buffer would still hold a block nobody needs.

## R3 Seam for the low-memory case

- Decision: the rule is a template taking a realloc-like and a free-like callable; the overload used
  by the core passes lambdas that call the CRT. `saltests` passes a fake allocator that fails chosen
  calls, always moves a successful block and keeps released blocks poisoned and marked, so a pointer
  to a released block is detected without undefined behaviour.
- Rationale: real memory exhaustion is not reproducible in a run (no fault injection in the product).
- Alternatives: a GUI probe - cannot exhaust memory between the two calls.

## R4 Other buffers of the same file (item Notes)

- `TextW` (SetText) and `SizeW` (SetSize) are released and replaced by one assignment each - no stale
  pointer. No change.
- `SetSize` writes `Size[0] = 0` before checking that `malloc(30)` succeeded - a NULL write under low
  memory; a separate defect, recorded as an Inbox item (scope rule).
- `CStaticText::SetText` (src/gui.cpp) frees `newText` - the successfully reallocated block `Text`
  still refers to - when a later `realloc` fails; a separate defect, recorded as an Inbox item.
