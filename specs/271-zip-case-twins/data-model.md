# Data model: 271

- **Listing case sensitivity** (`CZipList::CaseSensitive`, copied to `CPluginDataInterface::CaseSensitive`):
  TRUE when an entry is Unix-made or a folder of the listing holds case twins
  (`SalDirTreeHasCaseTwins`); FALSE otherwise. Decided once at the end of `CZipList::List`; equals
  `SALDIRFLAG_CASESENSITIVE` of the listing handed to the core.
- **Operation switch** (`CZipCommon::Unix`): starts as the listing's case sensitivity for copy /
  move / delete / view; still OR-ed with the selected entries' own `CZIPFileData::Unix`.
- No stored data, no registry, no file format change.
