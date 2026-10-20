# Research - 270-mask-filter-label-fits

## R1 - Where to measure

- Decision: in each dialog's `Validate`, first, with `DlgItemTextFitsU8(HWindow, id, &ti, MAX_PATH)`.
- Rationale: winlib's `CDialog` runs `Validate`, and `Transfer(ttDataFromWindow)` only when
  `Validate` left `ti` good (`winlib.cpp`, `case IDOK: if (!ValidateData() || !TransferData(...))`);
  a refusal there keeps the dialog open and nothing is read, selected, stored or written. Measuring
  before the syntax check gives one message for a text both too long and invalid.
- Alternatives: cut-free reads in `Transfer` (a heap buffer) - `Transfer` cannot refuse
  (winlib's TRACE_ET), and the callers' buffers are 260 bytes anyway.

## R2 - The volume label

- Decision: refuse at 260 bytes like the other fields, before `SetVolumeLabel`.
- Rationale: the field has no limit (an `EDITTEXT` without `EM_LIMITTEXT`, 30,000 units); a cut text
  keeps at least 86 UTF-16 units (3 bytes per unit at most), longer than any Windows file system
  label (NTFS / ReFS 32, FAT / exFAT 11, UDF 126 bytes); so the cut label was never applied, but
  the write was attempted with another text and the file system's message named that text's
  failure. Measured: 140 r-caron letters -> `SetVolumeLabel` with 129 (probe `vol`, before).
  The item's *Expected* names this refusal; a file-system-specific limit would be a new rule and a
  new message.
- Alternatives: `EM_LIMITTEXT` 32 - would refuse labels other file systems may accept, a behaviour
  change outside the item.

## R3 - The filter with "Don't use filter"

- Decision: measure regardless of the radio button.
- Rationale: `CFilterDialog::Transfer` reads the field into the masks string and the filter
  history in either case (measured: `flt-unused` stored `M*`).

## R4 - The hot path label edit

- Decision: read whole (`SalGetWindowTextU8Alloc`), store, let 251's page `Validate` refuse
  (`GetNameLen(i) >= MAX_PATH` -> `IDC_HOTPATH_NAME`).
- Rationale: the item's *Expected*; the page already keeps whole names (251) and reloads them
  whole (`PeekName`); `Dirty = TRUE` makes `Validate` check every slot at OK and on leaving the page.
- Alternatives: refusing in `LVN_ENDLABELEDIT` (return FALSE) - a box inside the list view's
  label edit, the typed text lost.
