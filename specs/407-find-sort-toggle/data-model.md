# Data model - feature 407

## CSalFindSortState (src/common/salfindsort.h)

| Field | Type | Meaning |
|---|---|---|
| Column | int | sorted column 0..4 (Name, Path, Size, Date, Time) or `SAL_FIND_SORT_NONE` (-1) |
| Descending | bool | the direction; false when Column is none |

Transitions (`SalFindSortNext(prev, column, toggle)`):

| prev | request | result |
|---|---|---|
| none | column c, toggle or not | (c, ascending) |
| (c, asc) | c, toggle | (c, descending) |
| (c, desc) | c, toggle | (c, ascending) |
| (c, any) | c, no toggle (internal) | (c, ascending) |
| (c, any) | d != c | (d, ascending) |

Requests that `SalFindSortColumnAllowed` refuses, and requests on an empty list, do not reach the
transition (the state stays). `ResetSort` (a new search) sets (none, ascending).

Lives in `CFoundFilesListView::SortState`, read and written only on the Find dialog's thread.
Nothing is persisted.
