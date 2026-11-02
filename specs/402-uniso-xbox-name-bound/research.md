# Research - 402-uniso-xbox-name-bound

## R1. What happens at HEAD

- Decision: the defect is real and reachable (probe before: 4 FAIL rows, names with the Debug heap's
  0xFD / 0xDD bytes, no box, the image deleted by a whole unpack).
- Rationale: `strncpy_s(fileName, data + offset + 14, len)` reads up to `len` bytes (it stops at a NUL);
  only `offset + 14 <= size` was checked.

## R2. Where the bound goes

- Decision: a header-only rule in `src/common/salisoxboxentry.h`, computed in 64-bit unsigned without
  wrap (`offset <= size && size - offset >= 14`, then `size - offset - 14 >= nameLen`); the next offset
  `(offset + 14 + nameLen + 3) / 4 * 4` is returned in 64 bits so the walk never wraps its 32-bit offset
  (a directory near 4 GiB: `((0xFFFFFFFF + 3) / 4) * 4` is 0 in 32 bits - the walk would restart).
- Rationale: rule 5 of the run (pure decisions in `src/common/` with saltests); the family of 223 (ISO
  9660 record bounds, inline) and 363 (`salisoudfentry.h`).
- Alternatives: an inline check in `ScanDir` only - not testable without the GUI.

## R3. What a damaged record does

- Decision: the walk's one box `IDS_ERROR_LISTING_IMAGE` with the directory's start sector,
  `SalIsoWalkBoxQuiet(Walk, false)`; the directory's walk ends (`break`) with
  `ret = SalIsoWalkAfterChild(ret, ERR_TERMINATE)` (= `ERR_CONTINUE`): the entries before it stay
  listed; in a sub-folder the parent goes on (400); at the top `ListDirectory` marks the listing
  incomplete (`walked != ERR_OK`) and returns TRUE, so the image opens, and a whole unpack keeps it.
- Rationale: the item's *Expected*; the root: conservative (spec Clarifications) - the Xbox root's read
  failure already returns `ERR_CONTINUE`.
- Alternatives: skip the entry and go on - rejected, its length is what is wrong, the next entry's place
  cannot be trusted; `return ERR_TERMINATE` - in the root it makes `ListDirectory` return FALSE (the
  whole listing fails, the entries before it lost from view).

## R4. Out of scope (recorded, not changed)

- The silent `break` on 0xFF padding that does not reach a sector end (upstream; ends the walk without a
  mark) - only its head check moves to the rule (same values); the behaviour stays.
- An empty name (len 0), the tree layout of XDVDFS directories walked linearly.
