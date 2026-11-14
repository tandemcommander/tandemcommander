# Data model: Portable build (feature 428)

The entities of [spec.md](spec.md) *Key Entities*, made concrete by [research.md](research.md).
No database; "data" here is files, folders, a private registry hive and named kernel objects.

## Edition

| Field | Values | Source |
|-------|--------|--------|
| edition | `normal` / `portable` | fixed at compile time: `TC_PORTABLE` defined for `salamand.vcxproj` when `TcEdition=portable` (R-06) |

Rules: never chosen at run time; nothing next to a normal executable makes it portable (FR-018);
plug-ins read it through `IsPortableEdition()` (API 109, R-07).

## Portable folder

```text
TandemCommander-<version>-portable\        ← unpacked from the ZIP (any name after a rename)
├── tandemcommander.exe                    ← portable edition (badge icon, TC_PORTABLE)
├── plugins\  lang\  iconsets\  toolbars\  … ← as in the normal tree (FR-003)
├── vcruntime140*.dll  msvcp140.dll  …     ← application-local runtime (077)
├── README-portable.txt  LICENSE  doc\…    ← package documents (contracts/package-layout.md)
└── settings\                              ← created no later than the first save
    ├── tandemcommander.reg                ← the configuration (persistent store)
    ├── tandemcommander.reg.bak            ← the previous complete file
    ├── tandemcommander.reg.damaged-<UTC>  ← only after a file that could not be read
    ├── BugReports\                        ← bug reports (was %LOCALAPPDATA%)
    └── Backups\                           ← backups before a settings import (was %APPDATA%)
```

- **Program folder** (`<P>`): the folder of the running executable, long-name form, no trailing
  backslash. Its **identity** = (volume serial, file ID) of the folder.
- **Scope** (`<scope>`): 16 lower-case hex digits = FNV-1a-64 of the identity bytes (pure,
  `salportable.h`). Same folder through any path → same scope; two folders → different scopes.

## Persistent store — `settings\tandemcommander.reg`

| Property | Rule |
|----------|------|
| Format | "Windows Registry Editor Version 5.00", UTF-16 LE with BOM — byte-for-byte the format of *Export Configuration* (174) |
| Root | every key under `[HKEY_CURRENT_USER\Software\Tandem Commander\Settings…]`; nothing outside (the parser refuses a file with other keys, 263) |
| Content | the whole session hive root including keys / values hidden from a normal export (`RemoveHiddenKeysAndValues` is **not** applied) |
| Paths | inside string values, the program folder at a path boundary is written as `$(PortableDir)`; expanded to the current `<P>` at load (R-03) |
| Write | to `tandemcommander.reg.tmp` in `settings\`, flushed, then `SalReplaceWithTempW`; the replaced file becomes `.bak` (FR-010) |
| Size | ~350 KB for a long-used configuration (measured 342 KB); refuse > 10 MB at load as the import does |

## Session folder and session hive

```text
%TEMP%\TandemCommander-portable-<scope>\
├── session.dat  (+ .LOG1, .LOG2)   ← the session hive, loaded with RegLoadAppKeyW
└── WebView2\                       ← web viewers' engine data (R-08)
```

- The **base key** (`SalCfgBaseKey()`) is the session hive's root; the configuration is at
  `Software\Tandem Commander\Settings` inside it (the same path as under HKCU).

### Store state (per process)

```text
          start
            │
   ┌────────▼─────────┐   delete session.dat fails (sharing)    ┌──────────────┐
   │ Opening          ├────────────────────────────────────────►│ Joined       │
   └────────┬─────────┘                                          │ (load shared │
            │ delete succeeds / absent                           │  session.dat)│
   ┌────────▼─────────┐                                          └──────┬───────┘
   │ Seeding          │ parse settings file → new session.dat           │
   │  file ok    → Clean                                                │
   │  file bad   → try .bak → ok: Clean + "restored" note               │
   │              → bad: rename .damaged-<UTC>, defaults, note           │
   │  file absent→ defaults (Clean, nothing written yet)                │
   └────────┬─────────┘                                                 │
            ▼                                                           ▼
        ┌───────┐  any change (notify)   ┌───────┐  2 s quiet / SaveConfig / exit  ┌────────────┐
        │ Clean ├───────────────────────►│ Dirty ├────────────────────────────────►│ Persisting │
        └───▲───┘                        └───────┘                                 └─────┬──────┘
            │                       ok                                                 │
            └──────────────────────────────────────────────────────────────────────────┤
                                                                                       │ fails
                                                                            ┌──────────▼─────────┐
                                                                            │ Unwritable         │
                                                                            │ message once per   │
                                                                            │ session; no more   │
                                                                            │ automatic attempts;│
                                                                            │ session goes on    │
                                                                            └────────────────────┘
```

- **Unwritable at start** (the `settings\` folder or the program folder cannot be written — probed by
  creating and deleting `settings\.probe-<pid>`): the store is *Unwritable* from the start: it seeds
  from the file (read-only access works) and shows the message once (FR-011, US6).
- **Exit**: Dirty → one synchronous persist; then all handles closed; try delete `session.dat`:
  success = last instance → delete the session folder (WebView2 best effort).
- **Stale clean-up at start**: every other `%TEMP%\TandemCommander-portable-*` whose `session.dat`
  can be deleted is removed.

### Pure start decision (`salportable.h`, saltests)

| session.dat | settings file | → action |
|-------------|---------------|----------|
| held by a live instance | any | join (load shared), no seeding |
| absent or deletable | readable, parses | seed from it |
| absent or deletable | readable, does not parse; `.bak` parses | seed from `.bak`, note |
| absent or deletable | neither parses | rename `.damaged-<UTC>`, defaults, note |
| absent or deletable | absent | defaults |
| absent or deletable | unreadable (I/O / access) | defaults **and Unwritable** (never overwrite a file we could not read) |
| cannot be created (TEMP full / denied) | — | refuse to start with a message (no registry fallback) |

## Named objects (per process, portable edition)

| Name | Purpose |
|------|---------|
| `Local\TandemCommanderPortable_<scope>_Start` | serialises the start decision of one copy |
| `Local\TandemCommanderPortable_<scope>_Store` | serialises persists of one copy |
| existing names + `_P<scope>` | process list, load / save lock, update-check claim (research R-05) |
| `Global\TandemCommanderFirstInstance_<SID>` | unchanged (shared `%TEMP%` cache) |

## Settings that change meaning in the portable edition

| Setting | Portable |
|---------|----------|
| `Update Level` (420/421) | ignored; only the check on / off exists |
| new: `Portable Password Note Shown` (DWORD, under the root) | set when the user ticks "Do not show this again" (FR-015a) |
| PictView `PrevWallpaper*` | in PictView's plug-in configuration (not `HKCU\Control Panel\Desktop`) |
| `Install *`, `Download Refused` (420) | never written |

## Package

| Field | Value |
|-------|-------|
| name | `tandemcommander-<version>-x64-portable.zip` |
| top folder | `TandemCommander-<version>-portable\` |
| location after build | `setup\output\` |
| contents | [contracts/package-layout.md](contracts/package-layout.md) |
