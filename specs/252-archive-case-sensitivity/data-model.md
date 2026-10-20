# Data model: 252

- **Listing flag** (`CSalamanderDirectoryAbstract` flags): `SALDIRFLAG_CASESENSITIVE` on the root
  (propagated to every sub-folder by the core's `SetFlags`).
  - 7-Zip / TAR listing: set before the first item; cleared after the last item unless the tree holds
    case twins. States: *building (CS)* -> *final CS* (twins) | *final CI* (no twins).
  - SFTP listing: `CASESENSITIVE | IGNOREDUPDIRS`, fixed.
- **Case twins**: within one folder, names A and B (dirs and files together) with
  `bytes(A) != bytes(B)` and (`SalNameOrderCompareCI(A, B) == 0` or `LegacyCompareCI(A, B) == 0`).
  Identical byte names (an appended TAR member) are not twins.
- **SalCaseTwinName**: `{ const char* Name; int Len; }` - a view of a listed name for the check.
