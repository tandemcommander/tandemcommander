# Closing report - 293-infoline-realloc-pair
Backlog item: the-information-line-keeps-using-a-freed-text-when-memory - The information line keeps using a freed text when memory runs out as it grows
Outcome: closed

## What changed

- `src/common/salgrowpair.h` (new, header-only): `SalGrowBufferPair` grows two parallel buffers;
  each successful `realloc` result is stored at once, the capacity rises only when both grew, a
  fresh block of a buffer that had none is released again on failure. The allocator is a parameter
  (the low-memory seam); the CRT overload calls `realloc` / `free` in lambdas.
- `src/stswnd.cpp` `CStatusWindow::SetText`: grows `Text` / `AlpDX` through it; the trace and the
  FALSE result are unchanged; after a failure the old text stays shown.
- `src/saltests/saltests.cpp` `TestGrowBufferPair293`: a fake heap that fails chosen calls, moves
  every successful block and marks released ones.
- `CHANGELOG.md` (0.1.11 unreleased), `specs/FEATURE-HISTORY.md` entry and index.

## Measurements (before / after, commands)

- Before (ad477c57, by reading): `SetText` stored the two `realloc` results only when both
  succeeded - a moved `Text` with a failed `AlpDX` (or the reverse) left a released block in the
  window. Reached by every `SetText` of the directory / information line with a longer text.
- After: reading proof in `fix-log.md` (*Checks*); `saltests` covers the four outcomes, retry,
  no-growth and the fresh line. Negative control (the old rule): `saltests: 25440 checks, 13 failed`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`.
- `saltests.exe`: `saltests: 25440 checks, 0 failed`.
- Probes: none - the low-memory case cannot be driven on the running program (spec Assumptions).

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD - two regressions of the rule were caught only by a hang /
crash of saltests; fixed (the test cases stop early), re-measured as counted failures (13 and 2).
NOTE 1 (unreachable branch) removed; NOTEs 2-4 accepted / recorded. Details in `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

Nothing.

## New Inbox items (slug - title)

- a-dialog-status-text-and-the-panel-size-field-crash-when - A dialog status text and the panel size field crash when memory runs out
