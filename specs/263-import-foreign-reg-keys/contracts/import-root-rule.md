# Contract - the import root rule (feature 263)

Internal to the core (not a plug-in interface).

## `SalRegKeyIsInsideRoot(const char* name, const char* root)` - `src/common/salregroot.h`

`name` is the key name after the root key of a .reg line (`Software\X` of
`[HKEY_CURRENT_USER\Software\X]`), `root` the allowed root (`Software\Tandem Commander\0.1`).

| name | result |
|---|---|
| equal to `root` (ASCII case-insensitive) | TRUE |
| `root` + `\` + anything (also nothing) | TRUE |
| `root` + any other character (`...\0.10`, `...\0.1x`) | FALSE |
| a parent of `root`, a different key, `\` + `root` (doubled backslash) | FALSE |
| empty, NULL; `root` empty or NULL | FALSE |

Non-ASCII bytes compare exactly (fail closed).

## `Parse(buf, registry, doNotDeleteHiddenKeysAndValues, onlyUnderHKCU = NULL)` - reglib

- `onlyUnderHKCU == NULL`: unchanged behaviour.
- otherwise: at every line starting with `[` (key or delete line), after the root key and the name
  are recognised and before anything is created, opened or deleted: when the root key is not
  `HKEY_CURRENT_USER` or `SalRegKeyIsInsideRoot(name, onlyUnderHKCU)` is FALSE, `Parse` returns
  `RPE_KEY_OUTSIDE_ROOT`. Lines before it may already have been applied - therefore the caller runs
  a memory pass first.
- Outside the core build (`INSIDE_SALAMANDER` with the code-page build not defined) a non-NULL
  restriction refuses every key line (fail closed); no such caller exists.

## `ImportConfiguration` (start-up import)

1. Pass 1 into the memory registry with the restriction. `RPE_KEY_OUTSIDE_ROOT` or any other error
   -> refuse.
2. Our root missing in the memory registry -> refuse as `RPE_NOT_REG_FILE` (no question).
3. Pass 2 into the system registry with the restriction.
4. Messages: `RPE_NOT_REG_FILE`, `RPE_KEY_OUTSIDE_ROOT` -> `IDS_IMPORTCFG_NOTREG`; the other codes as
   before. The file is never changed.
