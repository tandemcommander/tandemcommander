# Closing report - 295-statictext-grow-buffers
Backlog item: a-dialog-status-text-and-the-panel-size-field-crash-when - A dialog status text and the panel size field crash when memory runs out
Outcome: closed

## What changed

- `src/common/salgrowpair.h`: feature 293's rule generalized - `CSalGrowBuffer<T>` / `SalGrowBuf(ptr,
  extra)`, `SalGrowBuffersWith(reallocFn, freeFn, allocated, needed, bufs...)` (the test seam) and the
  CRT form `SalGrowBuffers(allocated, needed, bufs...)`: every growth attempted in order, each success
  stored at once, the capacity raised only when all buffers grew, fresh blocks of a failed growth
  released. `SalGrowBufferPair` (both forms) is now its two-buffer case.
- `src/gui.cpp` `CStaticText::SetText`: the five hand-written `realloc` calls (which freed earlier
  successful results - one of them the block `Text` still referred to - when a later call failed) are
  replaced by `SalGrowBuffers` with the same buffers, sizes and order; failure still returns FALSE
  with the old text shown.
- `src/stswnd.cpp` `CStatusWindow::SetSize`: writes `Size[0]` only after `malloc` succeeded.
- `src/saltests/saltests.cpp`: `TestGrowBuffers295` (846 checks).
- `CHANGELOG.md` (0.1.11 unreleased), `specs/FEATURE-HISTORY.md` (entry + index *Long paths, buffers*).

## Measurements (before / after, commands)

- Before (HEAD 9aa937a1, by reading - not reproducible without memory exhaustion between the calls):
  `SetText` frees `newText` after a later failure; `SetSize` writes before the NULL check. Recorded
  with `BL verify`.
- After: the seam proves the rule for every subset of the five (and two) growth calls failing; the
  reading proof in `fix-log.md` ties `gui.cpp`'s call (same sizes `l+20`, `(l+20)*2`, `(l+20)*4`,
  `l+23`, `(l+23)*2`; same order; same `Allocated`) and `SetSize`'s readers to it.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` → `BUILD SUCCEEDED` (only pre-existing regedt C4267 warnings).
- `saltests.exe` → `saltests: 26304 checks, 0 failed` (25,458 before the feature).
- Negative controls (header mutated, rebuilt, restored + touched): A old `SetText` rule 77 failed;
  B capacity raised on failure 95 failed; C fresh blocks kept 18 failed; D old pair rule (by the
  review) 122 failed; E `Extra` ignored 70 failed (exits after the review fix).
- No GUI probe (low memory cannot be produced on the running program; the item allows the seam).

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD 1 (the old-pair-rule control named in T005 was not
recorded) - recorded as control D with the review's numbers. SHOULD 2 (the CRT-form test wrote past
blocks unchecked, so a size regression hung `saltests` on a Debug CRT dialog) - fixed with `_msize`
checks before the writes; control E then fails cleanly. NOTEs: the seam mirrors `gui.cpp`'s buffer
list (covered by the reading proof); buffers may exceed `Allocated` after a failure (intended).

## Owed to a person (with the new person-step items)

Nothing.

## New Inbox items (slug - title)

None.
