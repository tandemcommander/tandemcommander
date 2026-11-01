# Research - 383-arc-typed-target-case

## R1 - Which rule re-spells the typed root

- **Decision**: `CSalamanderDirectory::ResolvePathCase` (feature 382, `SalArcPathResolveCase`).
- **Rationale**: it is the rule `ChangePathToArchive` applies to the same typed path (exact first;
  the listing's own comparison - a fold in a case-insensitive listing; in a case-sensitive listing
  only the ONE folder equal ignoring case and no file of that name), and it keeps the unresolved
  tail as typed - exactly FR-002 / FR-003. The packing root then names the folder the panel would
  open for the same text.
- **Alternatives**: `GetPathSpelling` / `SalArcPathRespell` (273) - refuses the whole path when any
  component is missing (NEWTAIL would keep `DOCS\New`) and does not resolve in a case-sensitive
  listing (TWINS); rejected. Re-spelling inside each plug-in - several plug-ins, plug-in ABI-adjacent;
  rejected (one core site serves all packers).

## R2 - Where the listing comes from

- **Decision**: a panel that shows the same archive (`Is(ptZIPArchive)`, `SalPathEqualOrdinalCI` of
  the archive name) whose recorded date and size equal the file's now and whose name does not lead
  elsewhere (145); otherwise `PackList` into a temporary `CSalamanderDirectory`.
- **Rationale**: the paste route (`salshlib.cpp` `DoPasteOperation`) reuses a panel's listing and a
  stored listing only with the same date and size; the edited-member check of 153
  (`salamdr3.cpp`) lists afresh with `PackList` and releases the plug-in data only after a
  successful listing. Both are precedents in the tree.
- **Alternatives**: always list (simpler, one more read when the other panel already shows the
  archive) - rejected for the common case; trust a panel's listing without a date / size check -
  a stale listing could pick a spelling that no longer exists; rejected.

## R3 - Listing failures

- **Decision**: any failure (format without lister, `PackList` FALSE, low memory) keeps the typed
  root; packing goes on. `PackList` reports its own error through `PackErrorHandlerPtr` (as when the
  archive is opened in a panel); a format whose unpacker cannot browse is not listed at all
  (checked first, no message).
- **Rationale**: FR-005 - never refuse a pack because of the re-spelling; never show a new error for
  a format the panel could not open either.

## R4 - Where in the sequence

- **Decision**: after the zero-size test (a zero-size archive is deleted and has nothing to list) and
  before the pack's `SetCurrentDirectory` / thread priority change; the re-spelled root is a copy,
  `path` / `secondPart` stay as typed for the error path that returns to the dialog.
