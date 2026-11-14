# Contract: the portable settings store (FR-005 – FR-013, FR-011a)

Applies to the portable edition only (`TC_PORTABLE`). The normal edition is unchanged:
`SalCfgBaseKey()` is the constant `HKEY_CURRENT_USER` there. Layout and states:
[data-model.md](../data-model.md); rationale: [research.md](../research.md) R-01 – R-05, R-10.

## Interface (core-internal, `src/portstore.h` / `.cpp`; pure parts in `src/common/salportable.h`)

```cpp
// Opens the store before anything reads the configuration (first in WinMainBody).
// FALSE = the program must not start (message already shown); never falls back to HKCU.
BOOL PortableStore_Open();
HKEY SalCfgBaseKey();                  // normal: HKEY_CURRENT_USER; portable: session hive root
BOOL PortableStore_IsWritable();       // FALSE after the unwritable message (US6)
void PortableStore_PersistNow();       // synchronous; called right after SaveConfig returns
void PortableStore_Close();            // at exit: persist if dirty, close, clean the session folder
const WCHAR* PortableStore_SettingsDir();   // <P>\settings (for About, bug reports, backups)
const char*  PortableStore_ScopeSuffix();   // "_P<scope>" (portable) / "" (normal)
```

Pure (saltests, `salportable.h`, header-only so plug-ins could use it):
`SalPortableScope(volumeSerial, fileIdBytes)`, `SalPortableSessionDirName(scope)`,
`SalPortableRelativize(text, programDir)`, `SalPortableExpand(text, programDir)`,
`SalPortableStartDecision(sessionState, fileState, bakState)`.

## Guarantees

1. **No registry writes outside the session hive** by the core in the portable edition (FR-006);
   the only HKCU / HKLM / HKCR access left is reading system information (a classified list is kept
   by `tools/check_portable_regsites.py` and checked in the build: every literal `HKEY_CURRENT_USER`
   / `HKEY_LOCAL_MACHINE` / `HKEY_CLASSES_ROOT` in `src/*.cpp` is either `SalCfgBaseKey()`-routed,
   marked `// portable: system read`, or compiled out under `TC_PORTABLE`).
2. **Every write is persisted**: a change anywhere in the session hive (core, plug-in interface, raw
   plug-in handles) is in `settings\tandemcommander.reg` at most 2 s after the last change, at once
   after `SaveConfig`, and at exit — unless the store is unwritable.
3. **Atomic**: the file is replaced only by a complete, flushed temporary file; the previous one is
   `.bak`. A kill at any moment leaves `tandemcommander.reg` complete (old or new) — SC-006.
4. **Lossless**: dump → parse reproduces every key, value name, type and byte (gate test, R-14),
   except the documented path relativization of string values.
5. **Paths**: the program folder inside string values is stored as `$(PortableDir)` (a `$(SalDir)` the user typed stays as typed) and expanded at load
   (R-03); nothing else in a value changes.
6. **Read-only**: when `settings\` cannot be written, the program runs on the seeded session hive,
   shows `IDS_PORTABLE_CANNOTSAVE` once per session, and never writes the settings anywhere else.
7. **Instances**: two processes of the same folder share one session hive and persist under
   `Local\TandemCommanderPortable_<scope>_Store`; processes of different folders and the installed
   program share nothing (FR-011a, the name table in research R-05).
8. **Clean exit**: when the last process of a copy exits, `%TEMP%\TandemCommander-portable-<scope>\`
   is removed (WebView2 best effort, retried by the next start's stale clean-up).
9. **Export / Import Configuration** in the portable edition read / write the session hive through
   reglib with the base key; files are interchangeable with the normal edition (FR-013).

## Start-up order (portable)

1. `PortableStore_Open()` — scope, start lock, stale clean-up, start decision, seed or join.
2. Language key, `CheckOnlyOneInstance` (scoped names), the normal load — all through
   `SalCfgBaseKey()`.
3. Skipped: `MigrateConfigurationRoot`, upgrade / old-configuration search, `config.reg` / `-c`
   import, 245 first-start offer, shell-extension registration, jump list.

## Messages (new strings, core `lang.rc2`, free slots of an existing bundle)

| Id | When |
|----|------|
| `IDS_PORTABLE_CANNOTSAVE` | the settings cannot be saved in `<settings path>` (start or a failed persist) — "changes made in this session will not be kept" |
| `IDS_PORTABLE_RESTOREDBAK` | the settings file could not be read; the previous copy was used |
| `IDS_PORTABLE_DAMAGED` | neither could be read; renamed to `<name>`, starting with default settings |
| `IDS_PORTABLE_NOTEMP` | the temporary folder cannot be used; the program cannot start |
