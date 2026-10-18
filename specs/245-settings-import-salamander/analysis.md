# Pre-specification analysis — feature 245

**Date**: 2026-10-18
**Purpose**: the evidence behind `spec.md`, gathered before the
specification from the 0.1.10 tree (`main` at `869d9690`) and a **read-only**
look at the live registry of the maintainer's machine. It is the input for
`/speckit-plan` (whose `research.md` should cite and re-measure it, not
re-derive it). Nothing was written to any registry key while gathering it.

## A1. Prior work this feature builds on

| Feature | What it settled | Consequence here |
|---|---|---|
| 032 / 046 rebrand | single registry root `Software\Tandem Commander\0.1`, "no config migration" (`src/mainwnd2.cpp:161-167`, `SALCFG_ROOTS_COUNT 1` `src/consts.h:2220`) | Constitution II forbids the **application** reading predecessor configuration — this feature needs an amendment |
| **057** altap-settings-migration | a standalone console utility `utils/migrate-altap-settings.cmd` (released in 0.1.3): category map, version generations, transforms, plugin matching by `DLL`, password portability, exclude-lists, backup/restore — `specs/057-altap-settings-migration/research.md` R1–R11, `contracts/category-mapping.md` | the in-app wizard reuses its **decisions**; it differs in being in-app, translated, and offering a *merge* mode (057 was replace-only) |
| 010 UTF-8 configuration (config 105) | packer/archiver sections of any config < 105 are rebuilt from defaults (`mainwnd2.cpp:2853`) | archivers are never imported |
| 084 archivers (config 106) | only 7-Zip and WinRAR remain; `PackMigrateArchiversTo106` | same |
| 078 panel tabs, 244 quick search filter, 028 theme, 071 command shell | TC-only settings absent from every source | never overwritten |
| 085 / 086 | passwords typed in addresses never reach a history; salts from `SalGenRandom` | imported histories are cleaned; password-blob format otherwise unchanged |
| 047 hot paths | `Icon` value added; `$` escaping only below config 47 | AS 4.0 / OS 5.0 hot paths load as-is |

**The 057 utility is now stale**: it stamps `Version\Configuration = 105`
(`utils/migrate-altap-settings.cmd:37,1011`) while TC is at 106, so a TC
started after the utility runs its < 106 upgrade (plugin auto-install,
archiver migration, forced save, reset of `Show Translation Is Incomplete`).

## A2. Sources found on the maintainer's machine (read-only probe)

| Root | `Version\Configuration` | Note |
|---|---|---|
| `Software\Altap\Altap Salamander 4.0` | 103 | genuine Altap 4.0; 30 plugins registered; 6 FTP bookmarks (5 scrambled passwords, no AES); `Language=czech.slg` |
| `Software\Open Salamander\5.0` | **105** | **not** genuine Open Salamander 5.0 (that writes 104): written by an early fork build (registers SFTP, MDVIEW, Folders, Portables) |
| `Software\Newt Commander\0.1` | 105 | development-only name: Newt Commander was never released (renamed 2026-08-01, first public release v0.1.0 as Tandem 2026-08-04) → not offered as a source |
| `Software\Tandem Commander\0.1` | 106 | the destination |

The historical root list (83 roots, Open Salamander 5.0 down to Servant
Salamander 2.x) is recoverable verbatim from `git show afcaa9eb --
src/mainwnd2.cpp`; the product-version ↔ config-version table is the comment
block `src/mainwnd2.cpp:26-145` (AS 4.0 = 103, 3.08 = 101, 3.0 = 84,
2.5 = 39; OS 5.0 = 104).

## A3. Encoding is not a conversion problem

Old programs wrote `REG_SZ` through the `A` API, but the registry stores
UTF-16; TC reads with `SalRegQueryValueExW8` (`src/salamdr6.cpp:2343-2350`,
`src/consts.h:2593-2597`), so old text arrives as correct UTF-8. The trap is
the reverse: an importer must never read via an `A` API / `CP_ACP`. Text
**inside `REG_BINARY`** stays code-page bytes and is copied verbatim: FTP
password plaintext (feature 116 keeps it byte-exact), `LOGFONTA` face names
(File Comparator), ZIP SFX favourites (encoding not verified — measure).
Master passwords are code-page bytes in both programs (`GetDlgItemTextA`).

## A4. Core configuration inventory (`SaveConfig` `mainwnd2.cpp:1264-2290`, `LoadConfig` `:2466-3840`)

| Section | Content | Import verdict |
|---|---|---|
| `Hot Paths\1..30` | Name, Path (`$`-escaped), Visible, (TC) Icon; 30 slots, slots 1–10 carry Ctrl+digit (`mainwnd1.cpp:213-304`, `fileswn0.cpp:1942-1979`) | **import**, merge or replace |
| `User Menu\n` | name, command, arguments, start folder, shell flags, show-in-toolbar, type (item/submenu/separator), icon (`mainwnd2.cpp:467-478,2981-3110`); unchanged since upstream | **import**, merge or replace; flag dead program paths |
| `Viewers`, `Alternative Viewers`, `Editors` | masks → external (0) / internal (1) / **plugin = −(index+1)** by position in `Plugins\1..N` (`fileswn5.cpp:1670`, `plugins1.cpp:2797-2808`) | **import, merge only**: plugin rows re-mapped by plugin identity, unmappable dropped; replacing would lose TC's own codeview/mdview masks, which a plugin adds only on first install (`plugins1.cpp:689-693`) |
| `Packers & Unpackers\*` | packer/unpacker lists, predefined packers (exe paths by UID), archive associations by index | **never** (010/084; indexes) — point to Archivers Autoconfiguration |
| `Colors` (+ `Panel Items Hilighting`), `Custom Colors` | scheme, colours (dual-type reader `salamdr2.cpp:2241-2277`) | import (take over) |
| `View Templates\0..9` | name, flags, columns; built-in names reseeded | import (take over) |
| `Viewer` | internal viewer options, font | import minus geometry/session values |
| `Configuration` (~141 values) + `Confirmation`, `Drive Special Settings`, `Copy Move Options`, `Find Options`, `Find Ignore` | options; per-value compiled defaults; never cleared on save | import by groups; exclude-list (A6) |
| `Configuration\* History` (14) + `Working Directories` | histories | optional, off by default, cleaned (085 `salurlpwd`) |
| `Default Directories` | per-drive last folder | import with 057 filter F2 (malformed values → modal box at every start) |
| `Left Panel` / `Right Panel` (+ TC `Tabs\n`, `Active Tab`), `Window`, `Find Dialog Window` | session and geometry | never |
| `Password Manager` | `Use Master Password` + `Master Password Verifier` (pair) | never overwritten (A7) |
| `Plugins\n`, `Plugins Order\n`, `Plugins.ver Version (x64/x86)` | registration (relative DLL, function masks, menus, icons, menu-item **HotKey**) | **never** — except user-assigned plugin hot keys (A5) |
| `Plugins Configuration\<key>` | each plugin's own configuration | import per plugin (A8) |
| `Version`, `Save In Progress`, `AutoImportConfig`, `Copy Is OK`, `Update Check` | markers / TC-only | never |

## A5. "Keyboard shortcuts" — what really exists

- **TC's own commands have fixed shortcuts**, in TC and upstream: the
  Keyboard page says "Shortcuts for Tandem Commander commands cannot be
  changed in this version." (`src/lang/lang.rc:1217`); no accelerator table
  is read from the registry (`keyboard.cpp:14`, `mainwnd4.cpp:1237`).
- **User-assignable**: shortcuts on **plugin menu commands** (Plugins Manager
  → Keyboard, `dialogs5.cpp:1181-1383`), stored as
  `Plugins\<n>\Menu\<i>\HotKey` with bit `HOTKEY_DIRTY` 0x10000 = set by the
  user (`plugins.h:2391-2409`); identified by the plugin's `DLL` + item `ID`;
  merge/integrity helpers exist (`HotKeysMerge` `plugins1.cpp:4029`,
  `HotKeysEnsureIntegrity` `:4058`, which clears a key that collides with a
  built-in one — 078 added Ctrl+Shift+PgUp/PgDn/T/W). Live: Altap 11 of 62
  plugin menu items carry a hot key, TC 9 of 42.
- **Key-behaviour options** (Panels page, `dialogs5.cpp:3376-3389`):
  `Quick Search Enter Alt`, `Use Shift For GoTo HotPath`, `Click to Quick
  Rename`, `Primary Context Menu`, `Single Click`, `Select/Deselect
  Directories` — same names and meaning as upstream.
- Hot-path keys follow the slot (Ctrl+Shift+digit assigns, Ctrl+digit goes).

## A6. TC-owned settings an import must never overwrite

`Theme Mode` (028), `Panel Tabs` (078), `Quick Search Filter` (244),
`Command Shell Program/Arguments/Preset` (071), language values (`Language`,
`Use Alternate Language for Plugins`, `Alternate Language for Plugins`,
`Language Changed` — read only at startup, `salamdr1.cpp:4111-4122`; zh-CN /
ru / uk modules are off), `Plugins.ver Version (x64/x86)`, `Enable/Disabled
Custom Icon Overlays` (machine-specific), `Main window icon index` (TC has 1
icon, upstream 4), `Conversion Table`, `Only One Instance`, dialog geometry
(`Last Focused Page`, `Configuration Height`, `* Expanded`, `Current Tip
Index`), the `Update Check` key.

Toolbar layouts (`Top/Middle/Left/Right ToolBar` = button-number lists):
057 R8 excluded them ("command ids drifted post-fork"), but the button table
`toolbar4.cpp:60-141` and its defaults were found unchanged (only 010/019/028
touched the file; live `Top ToolBar` strings identical). **Contradiction to
measure in planning** before offering them.

## A7. Passwords

- FTP blob kinds: `PasswordS` (signature 1, scrambled with a fixed table —
  portable as-is) and `PasswordE` (signature 2, AES-256 keyed only by the
  master password; no DPAPI, no machine binding) (`src/pwdmngr.cpp:481-583`).
  The format is identical in TC (085/086 changed only the salt source;
  `src/common/dep/crypt` untouched).
- A `PasswordE` blob is usable in TC only under the source's master
  password. Re-protection without new API: verify the typed old master
  password against the source verifier (`VerifyMasterPassword` logic
  `pwdmngr.cpp:794`), then drive FTP alone through
  `PME_MASTERPASSWORDREMOVED` / `PME_MASTERPASSWORDCHANGED`
  (`ftp.cpp:1108-1123`) — never the broadcast `CPlugins::PasswordManagerEvent`
  (`plugins2.cpp:3737`), which would hit SFTP too.
- The TC master password (it may protect SFTP secrets) is never replaced.
- Lowering protection (AES under a master password → scrambled, when TC has
  no master password) must not happen silently.
- `Host Address History` (FTP) may contain `ftp://user:pw@host`; FTP strips it
  only in memory at load (`ftp.cpp:691`) — a raw key copy would write it to
  TC's key (PRIVACY concern).

## A8. Plugins

- Registration is never imported: Altap plugins are interface ≤ 103 and are
  refused (`plugins.h:13` `PLUGIN_REQVER 104`); TC's SFTP, MDVIEW, CODEVIEW,
  Folders, Portables would drop out; stale metadata; plugins.ver counter.
- Configuration keys match by the stable `Configuration Key` literal; numeric
  `Plugins\n` positions differ (FTP is 13 in AS 4.0, 9 in TC). Match by `DLL`.
- Shipped in TC with the same key: 7zip (plugin version 3 → 5, plugin's own
  upgrade), Checksum, DBVIEWER, DISKMAP, File Comparator, FTP (37 = 37),
  PEVIEWER, PictView, RegEdit, Renamer, TAR (nothing user-set), UnCAB,
  UNDELETE, UnISO, ZIP. Not shipped (report, skip): Automation, CHECKVER,
  MMVIEWER, nethood, UnMIME, UnRAR (sources kept, off), IEVIEWER,
  SplitCombine, UnARJ, WMOBILE (removed in 007), Encrypt & Decrypt (never
  open-sourced). TC-only: SFTP, MDVIEW, CODEVIEW.
- `LoadConfiguration(parent, regKey, registry)` accepts any `HKEY` and
  **replaces** the plugin's settings; it is called once after the entry
  point (needs unload/reload + an `InitDLL` override key — a core change, no
  ABI change). The plugin's keys are opened `KEY_READ` (`regwork.cpp:77`).
  Saving is done only for loaded plugins (`plugins2.cpp:1750`).
- **Merging** (FTP bookmarks into existing ones: dedupe, renumber, re-map
  proxy UIDs and *Last Bookmark*) is impossible through `LoadConfiguration`
  (FTP calls `DestroyMembers()` first, `ftp3.cpp:444`): it needs either a
  plugin-side importer behind a new **append-only** call (interface 108,
  contract in `contracts/`) or core code that knows FTP's layout (layering
  break). No plugin's registry I/O changed since upstream except ZIP's
  widened favourite name (131).

## A9. Applying while TC runs

- No runtime reload of configuration exists; `LoadConfig` is startup-only
  (toolbar bands, window placement, focus — `mainwnd2.cpp:3563-3600,
  3900-3970`). The runtime model is `WM_USER_CONFIGURATION`
  (`mainwnd3.cpp:2246+`): change the in-memory objects, refresh, `SaveConfig`.
- TC rewrites its own sections from memory at exit (`AutoSave`,
  `mainwnd3.cpp:7298`) and every other TC instance does the same at its exit
  → writing the registry behind a running TC loses the import; other
  instances must be closed.
- The section loaders are reusable on another `HKEY` (`LoadViewers`,
  `LoadEditors`, `LoadHistory`, `CHotPathItems::Load`, `CViewTemplates::Load`,
  `LoadLogFont`, `LoadRGB/F`) **but** their conversions read the global
  `Configuration.ConfigVersion` (gates < 6, 13, 14, 16, 17, 22, 23, 28, 31, 32,
  44, 47, 64, 105, 106) and the worker `GetValue` shows a modal box on a
  wrongly typed or oversized value (`regwork.cpp:665,674`) → quiet reads,
  source version as context.
- **Do not revive the dormant upstream import** (`GetUpgradeInfo`,
  `FindLatestConfiguration`, `CImportConfigDialog`, `DeleteOldConfigurations`,
  `mainwnd2.cpp:656-1190`, `dialogs2.cpp:635-760`): it runs at startup,
  replaces everything, points `SALAMANDER_ROOT_REG` at the old root (so plugin
  self-saves and the critical-shutdown backup can write into it) and can
  **delete** the other product's keys. 032 FR-010 asked for its removal; only
  the root list was cut (a leftover).

## A10. Windows-level state

No core setting writes `HKCR` or Windows file associations; associations are
only read; the shell extension registers on every start regardless of
settings. The one Windows-visible effect of an import: changing hot paths
rebuilds the taskbar jump list (`mainwnd3.cpp:2322`, `jumplist.cpp:295`) —
normal product behaviour.

## A11. Observations outside the feature (candidates for the Inbox)

1. The startup `config.reg` / `-C` import (`salamdr2.cpp:3017-3060`) accepts a
   `.reg` file that holds no TC configuration after one question
   (`IDS_IMPORTCFG_NOTOURVER`, default No) and then writes **every** key of
   the file, including other products' keys or `HKEY_CLASSES_ROOT`.
2. 032 FR-010 leftover: the dormant upstream import machinery (A9).
3. `utils/migrate-altap-settings.cmd` stamps config 105 on a 106 product (A1).
4. `Main window icon index` load check off by one (`> MAINWINDOWICONS_COUNT`,
   `mainwnd2.cpp:3375`; the getter clamps, `dialogs4.cpp:672`) — harmless.
5. Two tags for 0.1.10 exist: `0.1.10` and `v0.1.10`.

## A12. Documents the feature must update (same change)

Constitution II (`.specify/memory/constitution.md:90-101`, version bump +
Sync Impact Report), `CLAUDE.md` *Product identity* ("never reads or writes
Open Salamander / Altap / Newt Commander keys"),
`architecture/12-project-reference.md:30-35`, `PRIVACY.md` (*Settings and
history*, *Saved passwords*: on request, read-only reading of the named
roots, passwords copied in stored form), `README.md:36` ("fully separate"),
`CHANGELOG.md` (unreleased section), `utils/README.md` (if the utility is
retired), help (`help/src/hh/salamand/customize_configuration.htm` + a new
page), `specs/FEATURE-HISTORY.md`. 032 FR-009/FR-010 and 046
`contracts/identity-map.md:30` stay unedited as history; the new spec states
that it supersedes them. New UI strings → two-stage `.slt` refresh (084).

## A13. Implementation outline (input for `/speckit-plan`, not binding)

1. **Pure rules in `src/common/`** (header-only where plugins need them) with
   `saltests`: source discovery and classification by root + version;
   category availability; per-item identity keys for merge (hot path by
   path with `SalPathEqualOrdinalCI`, user-menu item, viewer masks, FTP
   bookmark); hot-path slot placement; default-directory filter; exclude-lists;
   history cleaning (reuse `salurlpwd`); plugin re-mapping by `DLL`.
2. **Read-only source reader**: opens the source root `KEY_READ` only, quiet
   typed reads into heap buffers, never through `SALAMANDER_ROOT_REG`; builds
   an in-memory *import plan* (items, conflicts, skips with reasons).
3. **Wizard** (`DIALOGEX`, house style, Options menu item after *Import
   Configuration…*, free command id): source → categories + mode → details
   (conflicts, master password) → preview → apply → result.
4. **Apply**: refuse while another TC instance runs; export a full backup
   (existing export, feature 174) first; apply core categories to the
   in-memory objects through the `WM_USER_CONFIGURATION` path, then
   `SaveConfig`; plugin configurations: replace = unload, load from the
   source key read-only, save into TC's key; FTP merge = new append-only
   plugin call (interface 108, contract) or decision recorded otherwise;
   plugin hot keys through `HotKeysMerge` / `HotKeysEnsureIntegrity`.
5. **Passwords**: optional old-master-password step; targeted FTP
   re-protection; never replace TC's master password; explicit consent
   before lower protection.
6. **Documents** (A12), translations, help, GUI probes on the hidden desktop
   with registry backup/restore, fixture roots under a test override (never
   the maintainer's real Altap/Open Salamander keys written), refute-first
   review.
