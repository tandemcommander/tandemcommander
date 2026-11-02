# Research - 391-regedt-link-loop

## R1 How far does the loop go today?

- Decision: measured, not reasoned. Windows follows at most ~27-28 registry links within one open by
  name; the next open fails with ERROR_INVALID_PARAMETER (87). The copy wrote 38-55 keys, 27-28 levels
  deep; Find listed the same key 10-28 times; both ended with the open-error box (87).
- Rationale: the item expected the 512-unit name limit; the link limit comes first. Same defect.

## R2 How to tell "the link leads back into the walked tree"?

- Decision: by identity (feature 292's `AddOpenedRegKeyId`, the internal name of the opened key):
  a newly opened key leads back when it is, or holds, a key of the walk's chain.
- Rationale: covers a self-link, a link to any ancestor (also above the walk's start), and cycles
  through several links whose path text never repeats (`Cyc\<K>\L1 -> Cyc2`, `Cyc2\L2 -> Cyc\<K>`).
  A plain (non-link) child can never match: its identity is its parent's plus a name, longer than every
  chain entry, and by induction no chain entry lies inside a later one.
- Alternatives: (a) test each subkey with `RegKeyIsLink` (297) and then compare the link's target to the
  chain - two extra opens per key, and still needs the chain for cycles; (b) compare path text - misses
  cycles and alias roots; (c) refuse every link in Copy - changes behaviour the item keeps ("a link
  elsewhere may stay followed").

## R3 What does Copy show?

- Decision: feature 296's existing box "Can't copy a key to itself." naming the full source path of the
  refused key (OK skips, Cancel stops).
- Rationale: copying a key that is one of its own ancestors is copying a key into itself; no new string
  (no translation refresh); same buttons as 296's refusal. Limit: no Skip All (as 296).

## R4 What does Find do?

- Decision: skip silently. The skipped key's contents are those of a key already being searched, so no
  result is lost; a box in a long search would only interrupt it.

## R5 Cost

- One `NtQueryKey(KeyNameInformation)` on the already opened handle per key (no access right needed
  beyond the open), the chain test a length comparison for keys reached without a link. The walk's
  starting key uses `GetRegKeyIds` once.

## R6 Errors

- Below the start an unreadable identity (only a name longer than `SAL_REGKEYID_MAX`, or `NtQueryKey`
  missing) goes to the existing open-error box - fails closed. For the start the identity is best
  effort: a predefined root handle cannot be asked (292); without it the walk detects the loop one
  level later.
