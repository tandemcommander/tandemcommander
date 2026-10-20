# Data model - 263

No stored data changes. The entities the rule works on:

| Entity | Shape | Rule |
|---|---|---|
| Allowed root | `HKEY_CURRENT_USER` + `SalamanderConfigurationRoots[0]` (`Software\Tandem Commander\0.1`) | the only branch an import writes or deletes |
| Key line | `[<root key>\<name>]` | `<root key>` must be `HKEY_CURRENT_USER`; `<name>` inside the root (contract) |
| Delete line | `[-<root key>\<name>]` | the same rule as a key line |
| Parse result | `eRPE_ERROR`; new last member `RPE_KEY_OUTSIDE_ROOT` | the parser stops at the first line outside the root, before acting on it |

States of one import: read file -> pass 1 into memory (restricted) -> refused (`RPE_*` error or no
key under the root: message, nothing written) | pass 2 into the registry (restricted) -> done.
