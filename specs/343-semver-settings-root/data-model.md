# Data model: 343

## Configuration root (registry)

`HKEY_CURRENT_USER\Software\Tandem Commander\<root>` - `<root>` = `Settings` (new) or `0.1`
(legacy). Contents are unchanged by this feature: `Configuration`, `Plugins`,
`Plugins Configuration`, `Password Manager`, `Update Check`, histories, the values
`Save In Progress` (an interrupted save) and `AutoImportConfig` (upstream upgrade, dormant).
A root **has a configuration** when its `Configuration` subkey exists.

## Migration state (derived, not stored)

| Observed | Meaning |
|---|---|
| `Settings` with `Configuration` | migrated or fresh new configuration - use it |
| `Settings.migrating.63A7CD13` | an interrupted migration - delete, decide again |
| `Settings` without `Configuration` while `0.1` has one | leftover - replaced by the migration |
| only `0.1` (and/or `0.1.backup.63A7CD13`) | migrate |
| nothing | fresh start |

Transitions at start (contract `contracts/config-root-migration.md`):

```text
fresh ──────────────────────────────► uses Settings (created at first save)
legacy only ──migrate ok────────────► uses Settings; 0.1 kept unchanged
legacy only ──migrate failed────────► uses 0.1 for the session; message; retried next start
legacy only ──killed mid-copy───────► side key left ─► next start: deleted, migrate again
Settings has cfg ───────────────────► uses Settings (0.1 ignored)
```

## Release version

`MAJOR.MINOR.PATCH` + build number `N` (`spl_vers.h`); allowed steps from the previous release
`P = x.y.z`: `x.y.(z+1)` (PATCH, fixes only), `x.(y+1).0` (MINOR), `(x+1).0.0` (MAJOR); `N = N(P) + 1`.

## Changelog section

`## [Unreleased]` → (release) → `## [x.y.z] — YYYY-MM-DD` + lead `**Build N.** <Kind> release. …`.
