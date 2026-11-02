# Research - 387 regedt view text code page

## R1 - How big is the code-page copy?

- Decision: `WideCharToMultiByte(CP_ACP, 0, text, units, NULL, 0, NULL, NULL)` over all
  `size / 2` units (the terminating NUL(s) included), via `SalRegFindTextToCodePage` (278).
- Rationale: the exact count; the item's *Expected* names it; 278 tested the helper.
- Alternatives: `units * 4` worst case (wastes memory, still needs the count to write) - rejected.

## R2 - What happens when the conversion fails?

- Decision: write the value's UTF-16 data as stored (the switch-off form).
- Rationale: the item allows "reported or falls back"; the fallback adds no UI string and the
  viewer still shows the text (spec Clarifications). With flags 0 the call fails only for a code
  page the system lacks, so the branch is a guard.
- Alternatives: a new error string - rejected (UI string, translation refresh, no user benefit).

## R3 - Low memory for the copy

- Decision: the existing `IDS_LOWMEM` error, no file (as for the value's own buffer).

## R4 - The write check

- Decision: `WriteFile(...) && written == size`. The old `WriteFile(...) || written != size`
  took a short write as success and a failed write with `written != size` as success too.

## R5 - Measurement (before)

Python ctypes, the old sizing (space = units), on this machine (ACP 1250):
65001 `a€\0` -> ret 0, `61 AA 00` (needs 5); 65001 `čččč bar\0` -> ret 0, ` bar` lost (needs 13);
932 two hiragana + NUL -> ret 0, cut (needs 5); 1250 -> ret 9, whole.
