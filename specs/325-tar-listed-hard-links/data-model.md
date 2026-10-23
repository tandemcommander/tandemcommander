# Data model - 325-tar-listed-hard-links

All in memory, per operation of one `CArchive`.

- **Link map** (`std::unordered_map<std::string, std::string>`): archive name of every hard-link
  member read in the pass -> the (normalized) name it refers to. Built by the listing, by
  `DoUnpackArchive` and by `UnpackOneFile`.
- **Data sizes** (listing; `name -> unsigned __int64`): every data member listed so far (not a folder,
  not Ignored). A listed hard link's size = `SalTarListedLinkSize(links, sizes, linkName)`.
- **Deferred link** (`SDeferredLink`): `Name` (archive name of the link), `LinkName` (the name it
  refers to, as read), `Target` (where it goes, relative to the target path - `Name` minus the
  archive root). State: deferred in pass 1 -> written / copied / skipped by the user / reported.
- **Deferred names** (`unordered_set`): names of deferred links of pass 1 - a link naming one of them
  is deferred too.

Decision (`SalTarLinkDecideAsked(type, targetWritten, targetAsked, targetDeferred, linkHasDotDot)`):

| type | dotdot | written | deferred | asked | result |
|---|---|---|---|---|---|
| hard | yes | - | - | - | REPORT_MISSING |
| hard | no | yes | - | - | COPY |
| hard | no | no | yes | - | DEFER |
| hard | no | no | no | no | DEFER |
| hard | no | no | no | yes | REPORT_MISSING |
| symbolic | - | - | - | - | REPORT_UNSUPPORTED |
| other | - | - | - | - | NONE |
