# Research - 392-filter-dialog-backup

## R1: Backup the whole group, or check a copy?

- **Decision**: check the typed text in a local `CMaskGroup test` (`test.SetMasksString("",
  Filter->GetExtendedMode())`, the field read into `test.GetWritableMasksString()` with
  `MAX_PATH`, `test.PrepareMasks(errorPos)`); the panel's `Filter` is not touched in `Validate`.
- **Rationale**: the panel's group keeps its text, its mode and its prepared state exactly - a
  restoration from a backup (even a whole one) still leaves the group unprepared (`SetMasksString`
  sets `NeedPrepare`) and needs a second `PrepareMasks`; `operator=` would copy but rebuilds the
  prepared data too. The local group is the same class, so the verdict and `errorPos` are the same
  as before (FR-002). Precedent of a stack `CMaskGroup`: `CFilesWindow::SwitchToTab`
  (`CMaskGroup oldFilter`).
- **Alternatives**: a heap backup of `MAX_GROUPMASK` bytes + `SetMasksString` + `PrepareMasks`
  (restores the text, but rebuilds and resets the mode unless also saved); `CMaskGroup backup =
  *Filter` and assign back (works, more work, same result).

## R2: Does the accepted path depend on Validate's write?

- **Decision**: no. `CTransferInfo` calls `Validate` and, only when no `ErrorOn` was set,
  `Transfer(ttDataFromWindow)`, which reads the field into `Filter->GetWritableMasksString()` and
  prepares it (unchanged). The old `Validate` left the panel group holding the cut backup after a
  *good* check too; `Transfer` overwrote it - so nothing relies on that write.
- Mode on the accepted path: before, `SetMasksString(buf)` reset `ExtendedMode` to FALSE before
  `Transfer`; now `Transfer` keeps the panel's mode. Every `SetMasksString` call on a panel filter
  (`mainwnd2.cpp`, `paneltabs.cpp`, `fileswn1.cpp`) passes the default FALSE, so the panel's mode
  is always FALSE - no observable change.

## R3: Is a field over 259 bytes a concern here?

- `DlgItemTextFitsU8(HWindow, IDE_FILTER, &ti, MAX_PATH)` (feature 270) refuses it first and
  returns before the check; unchanged. The 1000-byte cap of `SetMasksString` stays (plug-in
  contract, feature 298 limit).
