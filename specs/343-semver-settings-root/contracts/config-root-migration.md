# Contract: the configuration root and its one-time migration (343)

Revised after review 1 (2026-10-25): unreadable keys are never taken for absent, a finished move
is recorded, a session running on the old root blocks other moves, leftovers are removed only at
the commit, the old backup is copied only when it is needed or copies cleanly.

## Keys and values (all under `HKEY_CURRENT_USER\Software\Tandem Commander`)

| Name | Role |
|---|---|
| `Settings` | the configuration root from this feature on (`SalamanderConfigurationRoots[0]`) |
| `Settings.backup.63A7CD13` | crash-time backup of the root (existing mechanism, new name) |
| `Settings.corrupted.63A7CD13` | a damaged root moved aside (existing mechanism, new name) |
| `Settings.migrating.63A7CD13` | side key of the move (the root's copy); never read as a configuration |
| `Settings.backup.migrating.63A7CD13` | side key of the move (the backup's copy) |
| value `Moved To Settings` (DWORD 1) in the parent key | a move has finished; written after the commit (and by a start that finds a moved root without it) |
| `0.1` | the root of 0.1.0–0.1.10; read by the move, never written after a successful one, never deleted by this feature |
| `0.1.backup.63A7CD13` | crash-time backup of the old root; copied by the move when present |

"Has a configuration" = the key exists **and** has the subkey `Configuration` (upstream rule).
Every probe is tri-state: exists / absent (`ERROR_FILE_NOT_FOUND` only) / unreadable (any other
error).

## Pure decision - `src/common/salcfgmigrate.h`

```c
enum CSalCfgMigrateAction { scmaUseNew, scmaMigrate, scmaFresh, scmaUseLegacy };

struct CSalCfgMigrateState
{
    BOOL NewHasConfig;       // Settings\Configuration exists
    BOOL NewUnreadable;      // Settings or Settings\Configuration exists but cannot be opened
    BOOL LegacyHasConfig;    // 0.1\Configuration exists
    BOOL LegacyBackupExists; // 0.1.backup.63A7CD13 exists beside the 0.1 root (alone it is never used, as in 0.1.x)
    BOOL LegacyUnreadable;   // 0.1, 0.1\Configuration or the backup cannot be opened
    BOOL AlreadyMoved;       // the parent's "Moved To Settings" is set
};

//   NewHasConfig || NewUnreadable          -> scmaUseNew     (never delete or replace a key we cannot read)
//   AlreadyMoved                           -> scmaFresh      (a missing Settings is the user's reset)
//   LegacyUnreadable                       -> scmaUseLegacy  (run on 0.1 as 0.1.x would; never start fresh over it)
//   LegacyHasConfig || LegacyBackupExists  -> scmaMigrate
//   otherwise                              -> scmaFresh
```

## Steps - `MigrateConfigurationRoot()` (`src/mainwnd2.cpp`)

0. Under `LoadSaveToRegistryMutex` (review 2: no start can slip in between a failing one and its
   session mutex): a session runs on the old root (mutex `Global\TandemCommanderLegacyCfgSession_<SID>`
   exists, or cannot be opened) → hold the mutex too, return *legacy root* with `*tellUser = FALSE`
   (nothing was tried; the running session told the user), touch nothing.
1. Probe the keys and the value, decide. The parent key cannot be opened → touch nothing, use the
   new root.
2. `scmaUseLegacy` → return *legacy root*. `scmaUseNew` / `scmaFresh`: delete side keys of an
   interrupted move if present; with `scmaUseNew`, a moved root and an old configuration but no
   record → write the record.
3. `scmaMigrate`:
   1. delete side keys of an interrupted move (one that cannot be read → fail);
   2. copy `0.1` → `Settings.migrating.63A7CD13` (`RegCopyTreeW`) and compare (failure → 4);
   3. if `0.1.backup.63A7CD13` exists: copy → `Settings.backup.migrating.63A7CD13` and compare; on
      failure drop it - fail only when `0.1` carries `Save In Progress` (then the backup is needed);
   4. commit: only now delete leftovers that hold no configuration (a `Settings` without
      `Configuration`, a `Settings.backup.63A7CD13`), rename the backup's side key, rename the root's
      side key (`RegRenameKey` - the root either does not exist or is complete), write the record
      (only when the root itself moved);
   5. failure: delete every side key and a backup renamed by this run; return *legacy root*.
   Every path that returns *legacy root* holds the session mutex before it releases the registry
   mutex.
4. Nothing in this function writes or deletes anything under `0.1`.

The caller (`WinMainBody`) on *legacy root*: `SalamanderConfigurationRoots[0] = SALCFG_LEGACY_ROOT`,
`HoldLegacyConfigSession()` (idempotent; the mutex for the session's lifetime),
`CfgMigrateFailed = *tellUser`.

Going back to 0.1.x after a move is not supported (the maintainer, 2026-10-25): the record is never
cleared by the program; a deleted `Settings` is a reset to defaults.

Compare = for every key of the source tree, the same subkey names exist in the copy, and every
value has the same name, type, size and bytes; the copy has no extra value or subkey (equal counts).

## Debug seam

`TC_CFGMIGRATE_FAIL_AT` (Debug build only): `copy`, `compare`, `rename` (the step reports failure),
`kill-after-copy` (`ExitProcess(3)` after the root's copy, before the compare), `exit-after-move`
(`ExitProcess(4)` after a successful move, before the program writes anything - the probe compares
the moved tree exactly).

## Message

`IDS_CFGMIGRATE_FAILED` (13753, core `lang.rc2`), shown once per start after the main window is
free (`WM_USER_CFGMIGRATE_FAILED`, retried by `IDT_CFGMIGRATE_FAILED`), with the new and old key
names as `%s`.
