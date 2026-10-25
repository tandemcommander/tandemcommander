# Contract: the configuration root and its one-time migration (343)

## Keys (all under `HKEY_CURRENT_USER\Software\Tandem Commander`)

| Name | Role |
|---|---|
| `Settings` | the configuration root from this feature on (`SalamanderConfigurationRoots[0]`) |
| `Settings.backup.63A7CD13` | crash-time backup of the root (existing mechanism, new name) |
| `Settings.corrupted.63A7CD13` | a damaged root moved aside (existing mechanism, new name) |
| `Settings.migrating.63A7CD13` | side key of the migration; never read as a configuration |
| `0.1` | the root of 0.1.0–0.1.10; read once by the migration, never written after a successful one, never deleted by this feature |
| `0.1.backup.63A7CD13` | crash-time backup of the old root; copied by the migration when present |

"Has a configuration" (both roots) = the key exists **and** has the subkey `Configuration`
(upstream definition, `FindLatestConfiguration`).

## Pure decision - `src/common/salcfgmigrate.h`

```c
enum CSalCfgMigrateAction { scmaUseNew, scmaMigrate, scmaFresh };

struct CSalCfgMigrateState
{
    BOOL NewHasConfig;        // Settings\Configuration exists
    BOOL LegacyHasConfig;     // 0.1\Configuration exists
    BOOL LegacyBackupExists;  // 0.1.backup.63A7CD13 exists
};

CSalCfgMigrateAction SalCfgMigrateDecide(const CSalCfgMigrateState& s);
//   NewHasConfig                              -> scmaUseNew
//   !NewHasConfig && (LegacyHasConfig || LegacyBackupExists) -> scmaMigrate
//   otherwise                                 -> scmaFresh
```

Leftovers (`Settings.migrating.63A7CD13`, and with `scmaMigrate` also a `Settings` without
`Configuration` and `Settings.backup.63A7CD13`) are deleted by the caller before it acts; they never
hold settings in use.

## Migration steps - `MigrateConfigurationRoot()` (`src/mainwnd2.cpp`), under `LoadSaveToRegistryMutex`

1. Read the state, decide. `scmaUseNew` / `scmaFresh`: delete the side key if present, return
   *new root*.
2. `scmaMigrate`:
   1. delete leftovers: `Settings.migrating.63A7CD13`, `Settings.backup.63A7CD13`, a `Settings`
      without `Configuration`;
   2. if `0.1.backup.63A7CD13` exists: `RegCopyTreeW` → `Settings.backup.63A7CD13`, compare
      (failure → step 4);
   3. if `0.1` exists: create `Settings.migrating.63A7CD13`, `RegCopyTreeW(0.1 → side)`, compare
      side with `0.1` (failure → step 4), `RegRenameKey(side → Settings)` (failure → step 4);
      return *new root*;
   4. failure: delete `Settings.migrating.63A7CD13` and `Settings.backup.63A7CD13` if this run made
      them; return *legacy root* (the caller sets `SalamanderConfigurationRoots[0]` to the old root
      string for the session and remembers to show `IDS_CFGMIGRATE_FAILED`).
3. Nothing in this function writes or deletes anything under `0.1`.

Compare = for every key of the source tree, the same subkey names exist in the copy, and every
value has the same name, type, size and bytes; the copy has no extra value or subkey. Names are
compared exactly (wide strings).

## Debug seam

`TC_CFGMIGRATE_FAIL_AT` (Debug build only): `copy` (the main copy reports failure), `compare` (the
compare reports a difference), `rename` (the rename reports failure), `kill-after-copy`
(`ExitProcess(3)` right after the main copy, before the compare - an interrupted migration).

## Message

`IDS_CFGMIGRATE_FAILED` (core `lang.rc2`), shown once per start after the main window is up, with
the old and new key names as `%s` arguments; text in the user's terms: the settings could not be
moved to the new place, the program uses them where they are for now and will try again at the
next start; nothing was deleted.
