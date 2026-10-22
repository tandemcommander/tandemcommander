# Data model - feature 297

No stored data. The objects the operations look at:

- **Registry key** (root, path): a key the user selected, or a key of its tree, reached by name.
- **Registry link**: a registry key created with `REG_OPTION_CREATE_LINK`; opened as a link
  (`REG_OPTION_OPEN_LINK`) it holds the value `SymbolicLinkValue` of type `REG_LINK` (the internal
  name of the key it points at); opened by name, every operation goes to that other key.
- **Link target**: the key a link points at - never selected by the user in these operations; must
  stay unchanged (may not exist: a dangling link).

States of a key at one level of a recursion:

| Test (opened as a link) | Delete | Move / Quick Rename |
|---|---|---|
| no such key (`ERROR_FILE_NOT_FOUND`) | as before (its own open reports it) | as before |
| key, no `SymbolicLinkValue` / other type | as before | as before |
| link (`REG_LINK`) | the link itself removed (`NtDeleteKey`), nothing below | refused: `IDS_REMOVESOURCE` + `ERROR_NOT_SUPPORTED` box |
| other error | open-error box (fails closed) | open-error box (fails closed) |
