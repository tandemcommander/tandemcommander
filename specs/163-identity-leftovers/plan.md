# Plan: 163

- `fileswn0.cpp` `SelectFocusedItemAndGetName(CSalHeapString&)` (declaration `fileswnd.h`): the
  whole name on the heap; the ten callers (`fileswn5.cpp`, `fileswn7.cpp`, `mainwnd3.cpp`) keep a
  `CSalHeapString temporarySelected` and pass `.Text()` to `UnselectItemWithName`.
- `UnselectItemWithName`: `SalNameEqualOrdinalCI`, exact name (length + bytes) first.
- `find.cpp` `CFindIgnore::Contains` relative kind: `SalFindIgnoreRelativeMatch`
  (`src/common/salfindignore.h`, header-only on `SalPathHasPrefixOrdinalCI`), saltests.
- `plugins/undelete/fs2.cpp` `ViewFile`: the key in one `_snprintf_s` into a buffer sized for the
  maxima; an overflow refuses (trace, no view) instead of cutting.

Constitution: PASS (no string, interface, registry, installer or public-claim change; incremental;
plug-in ABI untouched - the changed methods are core-internal).
