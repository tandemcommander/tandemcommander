# Data model - 292

- **Key identity** - text, the registry's full internal name of a key
  (`\REGISTRY\MACHINE\...`, `\REGISTRY\USER\<SID>\...`, `\REGISTRY\USER\<SID>_Classes\...`), at most
  `SAL_REGKEYID_MAX - 1` units; compared case-insensitively, element by element.
- **Identity set** (`CSalRegKeyIds`) - up to `SAL_REGKEYIDS_MAX` (6) identities of one key path:
  one for an existing key; under `HKEY_CLASSES_ROOT` one per half that holds it (the root: two); a
  target key not yet existing has those of its parent joined with its name.
- Sets built per operation: panel folder, target folder (once); per selected key: source key
  (opened), target key (opened, or the target folder joined with the new name).
- No stored data, no registry layout change of the product.
