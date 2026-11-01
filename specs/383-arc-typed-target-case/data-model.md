# Data model - 383-arc-typed-target-case

- **Typed root** (`secondPart + 1` in `FilesAction`): UTF-8, below `MAX_PATH` bytes (checked by the
  existing guard), components separated by `\`, an optional trailing `\` (the dialog requires one for
  a folder target). Never modified; copied into `packRoot`.
- **Resolved path** (`ResolvePathCase` output): the typed root without leading / trailing `\`, each
  leading component that names an existing folder replaced by the listing's name (same byte length -
  the listing's comparisons only equal names of equal length), the rest as typed.
- **Pack root** (`packRoot`): the typed root with the resolved bytes laid over its middle part
  (`SalArcPathApplyResolved`); equal to the typed root when nothing resolved or the lengths differ.
- **Listing source**: a panel's `ArchiveDir` (borrowed, never freed here) or a temporary
  `CSalamanderDirectory` with its plug-in data (owned, released after the resolution).
