# Data model - 349-uniso-hfs-folder-order

## CSalHfsFolderOrder (src/common/salisonamefit.h)

One listing's folder records, by catalog ID.

| Field | Meaning |
|---|---|
| Link.Id | the folder's catalog ID (as stored; only compared) |
| Link.Parent | its parent's catalog ID (the record key's parent) |
| Link.Record | its record index in the catalog (rising in Add order) |
| Link.Taken | the record was taken (listed, left out, skipped) |
| Link.Stamp | the walk that last met it (loop guard) |
| ById | link indices sorted by (Id, Record) - Find gives the first record of an ID |

Operations:

- `Add(id, parent, record)` - records in rising order; false = out of memory or not rising.
- `Seal()` - builds `ById`; false = out of memory.
- `IsTaken(record)`, `Take(record)` - by record index (binary search); records not in the table are
  never taken (`Take` ignores them).
- `Pending(parentId, out)` - `SAL_HFS_PENDING_OK`: `out` = the records of the folders above an entry under
  `parentId` not taken yet, outermost first (empty when the parent is taken, or is no folder of the
  table); `SAL_HFS_PENDING_LOOP`: the walk met a folder twice - `out` = the records of the walk, each
  once (the caller leaves them out); `SAL_HFS_PENDING_NO_MEMORY`.

State: a record goes untaken -> taken once; `Pending` never returns a taken record.
