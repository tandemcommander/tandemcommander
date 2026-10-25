# Contract: importing a configuration file written for the `0.1` root (343)

Extends `specs/263-import-foreign-reg-keys/contracts/import-root-rule.md`.

## Pure rule - `src/common/salregroot.h`

```c
// TRUE when 'name' (the key name after "HKEY_CURRENT_USER\") is 'legacyRoot' or below it and the
// same path under 'root' fits 'out'; 'out' = root + the rest of 'name' after legacyRoot.
// FALSE (and an empty 'out' when outSize > 0) otherwise: NULL / empty arguments, 'name' not
// inside 'legacyRoot' (same comparison as SalRegKeyIsInsideRoot), or the result does not fit.
BOOL SalRegMapLegacyRoot(const char* name, const char* root, const char* legacyRoot,
                         char* out, int outSize);
```

Examples (`root` = `Software\Tandem Commander\Settings`, `legacyRoot` = `Software\Tandem Commander\0.1`):

| name | result |
|---|---|
| `Software\Tandem Commander\0.1` | `Software\Tandem Commander\Settings` |
| `Software\Tandem Commander\0.1\Configuration` | `Software\Tandem Commander\Settings\Configuration` |
| `software\tandem commander\0.1\Plugins` | `Software\Tandem Commander\Settings\Plugins` |
| `Software\Tandem Commander\0.10` | FALSE (a sibling) |
| `Software\Tandem Commander\0.1x\A` | FALSE |
| `Software\Tandem Commander\Settings\A` | FALSE (already inside the root; not a legacy name) |
| `Software\Other` | FALSE |

## Parse

`Parse(buf, reg, doNotDeleteHiddenKeysAndValues, onlyUnderHKCU, legacyRoot = NULL)`: for a key
line or delete line under `HKEY_CURRENT_USER` that `SalRegKeyIsInsideRoot(name, onlyUnderHKCU)`
rejects, `SalRegMapLegacyRoot(name, onlyUnderHKCU, legacyRoot, ...)` is tried; a mapped name is
used in place of the original for that line. A name neither inside nor mappable keeps returning
`RPE_KEY_OUTSIDE_ROOT`. Parent lines (`SalRegKeyIsParentOfRoot`) behave as before.

## Callers

`ImportConfiguration` (`salamdr2.cpp`) passes `SALCFG_LEGACY_ROOT` (`Software\Tandem Commander\0.1`)
for both its memory and registry parse - the menu command and the start-up `config.reg`
(installation folder, `%APPDATA%\Tandem Commander`, `-C`). When the session itself runs on the
legacy root (failed migration, contract `config-root-migration.md` step 4), `onlyUnderHKCU` is the
legacy root and no mapping happens.
