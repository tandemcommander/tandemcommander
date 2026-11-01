# Data model - 382-arc-case-twins-path

- **Archive listing** (`CSalamanderDirectory`): folders (`Dirs`, each with a sub-listing) and files;
  `Flags & SALDIRFLAG_CASESENSITIVE` (propagated to every sub-listing by `SetFlags`).
- **Typed path inside the archive** (`ZIPPath` after `SetZIPPath`): `\`-separated components;
  after this feature, its leading components that resolve carry the listing's spelling.
- **Component resolution** (per component, in its parent folder):
  exact (first `SalDirStrCmpEx` match) -> else, case-sensitive folder only: unique sibling equal
  ignoring case (accept by `StrICmpEx`, ambiguity by `StrICmpEx` or `SalNameCompareOrdinalCI`) ->
  else unresolved (rest kept as typed).

No stored data, no registry, no plug-in data changes.
