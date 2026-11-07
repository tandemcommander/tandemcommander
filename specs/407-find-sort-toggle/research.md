# Research - feature 407

## R1 Folders in the descending order

- Decision: folders stay grouped before files in both directions; each group is reversed.
- Rationale: the item says "treated as for the panel"; the panel sorts `Dirs` and `Files` separately
  and always shows folders first (`SortFilesAndDirectories`, `fileswn3.cpp`), with `reverse`
  applied to every key of the comparison (`LessTimeNameExt`, `sort.cpp`).
- Alternatives: a pure column sort (folders mixed with files, as Explorer's date sort) - rejected:
  not the panel's model, and it would change the first (ascending) order users know.

## R2 Which requests toggle

- Decision: every user request: header click (`LVN_COLUMNCLICK`), View menu `CM_FIND_NAME/PATH/TIME/SIZE`
  and the list's Ctrl+F3..F6 (they post the same commands). Internal sorts (`OnHideDuplicateNames`)
  never toggle; they sort ascending.
- Rationale: the panel's View menu calls `ChangeSortType(type, TRUE)` (toggle); one rule for all routes.

## R3 Reverse inside the tie-break chain

- Decision: the whole comparison result inside a group is negated (`SalFindSortOrder`), so the
  tie-break columns are reversed too - the descending order is the exact reverse of the ascending
  one within each group.
- Rationale: the panel does the same (`reverse` in `CmpNameExt` as well).

## R4 Duplicates

- Decision: `CompareDuplicatesFunc`'s result is negated as a whole (`SalFindSortDirected`).
- Rationale: its key is (name or size, the other, group); reversing the whole key keeps every
  group contiguous, and `SetDifferentByGroup` shades by group afterwards. The allowed columns are
  unchanged (`SalFindSortColumnAllowed` = the old guards of `SortItems` and the View menu).

## R5 The header arrow

- Decision: `HDM_GETITEMW` / `HDM_SETITEMW` with `HDI_FORMAT` on the list's header; the new format
  = old format without `HDF_SORTUP | HDF_SORTDOWN`, plus the one for the sorted column.
- Rationale: comctl32 v6 is in the manifest; the wide message carries no text (format only), so
  no code-page conversion is involved.

## R6 When the sort is forgotten

- Decision: `CFindDialog::StartSearch`, next to `ListView_SetItemCount(..., 0)`, for every kind of
  search (the list is in search order again).

## R7 Double QuickSort

- Decision: the normal mode sorts once (the second identical `QuickSort` removed; finding fixed on
  the way, severity 1 - only wasted time).
