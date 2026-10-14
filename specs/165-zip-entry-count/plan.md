# Plan: 165

- `src/common/salzipcount.h` (header-only): `SalZipEndRecordCounts` (the 16-bit fields and
  whether zip64 is needed), `SalZipReadEntryCount`, `SalZipCountCentralRecords`; saltests.
- `src/plugins/zip/typecons.h`: `CEOCentrDirRecordEx` (in memory only) gets `TotalEntries64`,
  `DiskTotalEntries64`.
- `common.cpp`: set after the end record is read, replaced from a zip64 end record.
- `add.cpp`: every reset and increment mirrored; `LoadCentralDirectory` takes the walked record
  count; `WriteEOCentrDirRecord` derives the 16-bit fields and writes the zip64 records for the
  counts (not for a self-extracting archive); the locator's disk count `DiskNum + 1`.
- `del.cpp`: both deletion paths mirrored.

Constitution: PASS (the archive format follows APPNOTE; no interface, string, registry change).
