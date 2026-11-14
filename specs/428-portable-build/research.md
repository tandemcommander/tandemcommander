# Research: Portable build (feature 428)

Phase 0 of `/speckit-plan`, 2026-11-14. Inputs: [spec.md](spec.md) (15 clarifications),
[state-inventory.md](state-inventory.md) (what the program stores outside its folder today), a
second code sweep (build layout, named objects, plug-in API, update check, `$(SalDir)`, config
entry points) and **measurements** of private registry hives on this machine (probe scripts in
the session scratchpad, results below). Each decision: what was chosen, why, what else was
considered.

## Measurements (2026-11-14, Windows 11 26300, NTFS, standard user)

`RegLoadAppKeyW` on a file `settings.dat`:

| # | Case | Result |
|---|------|--------|
| T1 | file absent, writable folder | created: `settings.dat` 8 KB + `.LOG1` 8 KB + `.LOG2` 16 KB; value written, `RegFlushKey` 0 |
| T2 | reopen in a new process | value read back |
| T9 | does it appear in `HKEY_USERS`? | **no** — an app hive is private to the processes that load it |
| T4 | two processes load the same file at once | both succeed and **share it live** (one's write is read by the other) |
| T11 | copy the file while a process holds it | **fails** (sharing violation); after the holder exits the copy works (T12) |
| T5 | file has the read-only attribute | loads, writes **persist** (the attribute does not protect the hive) |
| T6 | folder denies write / create to the user, hive present | **`RegLoadAppKey` = 5 (access denied) even with `KEY_READ`** — the hive needs its logs |
| T6b | same, no hive | 2 (not found); in a *writable* folder `KEY_READ` **creates** the file |
| — | same file through two paths (`subst Q:`) at once | shared (the kernel identifies the file, not the path) |
| — | the maintainer's real configuration copied in (349 keys, 1,858 values; `reg export` 342 KB) | hive 512 KB; full write + flush 117 ms, cold load + full read 66 ms (PowerShell, .NET; native is faster) |

Not measured (no FAT32 / exFAT volume, no share, no elevation available): a hive on FAT32 / exFAT
and on SMB. The maintainer chose **not to measure and to take the design that works on every
medium** (R-01).

## R-01 Where the configuration lives at run time and on disk

- **Decision**: a **session hive** (private registry hive loaded with `RegLoadAppKeyW`) in a
  per-copy folder in the user's `%TEMP%`, built at start from **`settings\tandemcommander.reg`**
  (the program's own export format, "Windows Registry Editor Version 5.00", UTF-16) and written
  back to it after every change (debounced) and at exit, through a temporary file and
  `SalReplaceWithTempW`, keeping the previous file as `tandemcommander.reg.bak`.
- **Rationale**:
  - Plug-ins receive real `HKEY`s and some use them with Win32 functions directly (FTP, nethood,
    automation — inventory §1); a hive is a real registry, so **every plug-in works unchanged**
    (FR-009, constitution V) and the core keeps its registry code.
  - The file on the stick is a plain file written by replace: works on **any** file system
    (FAT32, exFAT, SMB — unmeasured for hives), on **read-only media** (T6: a hive there cannot even
    be loaded; a text file can be read), and the portable folder **can be copied while the program
    runs** (T11: a loaded hive cannot).
  - Replace-with-temp + `.bak` gives FR-010 (never half-written); the session hive's own logs keep
    the session consistent.
  - The text is the same format as *Export Configuration*: a portable `tandemcommander.reg` imports
    into an installed copy and an installed export can seed a portable one (FR-013), and the
    maintainer can read and diff it (Q-03 settled as a side effect).
  - Measured cost: ~0.5 MB hive, tens of ms to load / dump (SC-009).
- **Alternatives considered**:
  - *Hive file directly in `settings\`* — simplest and nothing leaves the stick, but unmeasured on
    FAT32 / exFAT / SMB, unusable on read-only media (T6), and it locks the folder while running
    (T11). Rejected by the maintainer's choice ("decide without measuring").
  - *An own key-value file with an emulated registry for plug-ins* — plug-ins with raw `HKEY`s would
    break (ABI). Rejected.
  - *Redirecting HKCU (`RegOverridePredefKey`)* — the whole process (shell, COM, common dialogs)
    would read and write the private hive instead of the user's registry; far-reaching side effects.
    Rejected.
- **Accepted risk** (the maintainer's choice): after a **crash** the session hive (the user's
  configuration, including saved passwords protected only as today) stays in `%TEMP%` of that PC
  until the next start of *any* portable copy there (R-04 cleans it). `%TEMP%` is the user's own
  profile folder (other users cannot read it).

## R-02 Persist triggers

- **Decision**: a worker thread waits on `RegNotifyChangeKeyValue` (subtree, names + values) of the
  session hive root; a change marks the store dirty and a dump runs **2 s after the last change**
  (debounce), under the per-folder store lock (R-05). In addition: a synchronous dump right after
  every `SaveConfig` (so *Save Configuration* and *Save on exit* are durable when they return) and
  at exit if dirty.
- **Rationale**: catches **every** write — core, plug-ins through the interface and plug-ins with raw
  handles, the update-check state written "at once" (123) — without touching any call site. A crash
  loses at most the last ~2 s of writes that had not been dumped; *Save configuration on exit*
  semantics are unchanged.
- **Alternatives**: dump only after `SaveConfig` (misses immediate writes and plug-ins' own saves);
  dump after every single write (hundreds of dumps during a save). Rejected.

## R-03 Path relativization (Q-17)

- **Decision**: done **in the dump / load layer**, not per setting. At dump every string value
  (`REG_SZ`, `REG_EXPAND_SZ`, each string of `REG_MULTI_SZ`) has every occurrence of the program
  folder at a path boundary replaced by `$(PortableDir)`; at load `$(PortableDir)` is replaced by the
  current program folder. (First drafted as `$(SalDir)`; the gate test showed the program's own
  `$(SalDir)` carries a trailing backslash in commands — `ExecuteExpSalDir` — and none in initial
  folders, so a user's `$(SalDir)tools\x.exe` would have become `E:\TCtools\x.exe`. A token of the
  store's own leaves every `$(SalDir)` the user typed untouched.) The comparison is the file system's (`SalPathHasPrefixOrdinalCI` rules, 092); the
  program folder is the long-name form (`GetLongPathNameW`) without a trailing backslash; a
  boundary is end of string or a character that cannot continue a name (`\`, `"`, space after a
  quoted path is not needed — the next character must be `\` or end or `"`, `;`, `,`, `|`).
  Pure functions in `src/common/salportable.h` with saltests.
- **Rationale**: one place covers the core and every plug-in (also raw-handle writes); the program
  in memory and its dialogs always see ordinary absolute paths of the current location (FR-012:
  "never a path cut", no `$(SalDir)` surprises in fields that do not expand variables, e.g. panel
  paths). Measured fact: `$(SalDir)` is already understood by viewers, editors, the user menu, hot
  paths, archiver executables and the command shell (`execute.cpp` tables) — the file stays
  meaningful even read by a human.
- **Edge**: a value the user typed as `$(SalDir)…` is never touched. Binary values are not touched (checked: no enabled plug-in stores paths in
  `REG_BINARY`). Plug-in `DLLName` is already stored relative to `plugins\`.
- **Alternatives**: per-setting conversion at each save / load site (dozens of sites, plug-ins not
  covered); storing `$(SalDir)` in memory (shows in dialogs, breaks fields without variables).

## R-04 The per-copy session folder and its life cycle

- **Decision**: `%TEMP%\TandemCommander-portable-<scope>\` with `session.dat` (+ its logs) and
  `WebView2\` (R-08); the disk cache stays where it is today (R-09). `<scope>` = 16 hex digits of a 64-bit
  FNV-1a hash of the program folder's **volume serial number + file ID** (`GetFileInformationByHandleEx`
  on the folder) — the identity, not the path (measured: the same file through two paths is one
  hive).
  - Start (under the per-folder start lock): try to delete `session.dat`; **success** = no live
    instance holds it → stale (crash) or absent → build a fresh session hive from
    `settings\tandemcommander.reg`; **sharing violation** = another instance of this copy runs →
    load the same `session.dat` (shared live, like two instances on HKCU today).
  - Exit: close every handle; the last instance's delete of `session.dat` succeeds → delete the
    whole session folder (WebView2 best effort — its browser processes may linger).
  - **Stale clean-up of other copies**: at start, for every other `TandemCommander-portable-*`
    folder, the same delete test; an unheld one is removed with its folder (a crashed copy's data
    does not stay on a stranger's PC longer than the next portable start there).
- **Rationale**: the kernel's own lock on a loaded hive is the truth about "is a copy running" —
  no counters to go stale.
- **Alternatives**: a reference count in a file or a named semaphore (stale after kills); per-path
  hash (two paths of one folder would build two hives).

## R-05 Instance scoping (FR-011a)

Measured names (second sweep) and the decision for each:

| Object | Today | Portable |
|--------|-------|----------|
| Process list `TandemCommander01ProcessList` / `…Mutex` / `…Event` / `…EventProcessed` (*Only one instance*, break / terminate / highlight) | per session | name + `_P<scope>` |
| `Global\TandemCommanderLoadSaveRegistry_<SID>` (load / save lock) | per user | + `_P<scope>` (it guards the store of this folder) |
| `Local\TandemCommanderUpdateCheck` | per session | + `_P<scope>` |
| new: per-folder start lock and store lock | — | `Local\TandemCommanderPortable_<scope>_Start`, `…_Store` |
| `Global\TandemCommanderFirstInstance_<SID>` (gates the start-up offer to clear `SAL*.tmp` in `%TEMP%`, also `IsFirstInstance3OrLater` for ZIP) | per user | **kept per user** — the disk cache in `%TEMP%` is shared by every copy; scoping it would let a portable first instance offer to delete the installed copy's live cache |
| `Global\TandemCommanderLegacyCfgSession_<SID>` (343) | per user | never created (migration skipped) |
| Shell-extension shared memory / events | per session | not created (FR-006a) |
| File Comparator `RemoteComparator …` objects, `FCREMOTE<pid>` | global | + the scope suffix via the plug-in API (R-07) |
| Main window class, `RegisterWindowMessage` names | — | unchanged (no instance detection by them) |

## R-06 How the edition is built (Q-07, Q-24, Q-25)

- **Decision**: one MSBuild property `TcEdition=portable` for the **whole solution**:
  - new `src/Directory.Build.props` defines `TcOutSuffix` = `_portable` when `TcEdition=portable`,
    else empty; the 19 project files / sheets that spell
    `tandemcommander\$(Configuration)_$(ShortPlatform)\` append `$(TcOutSuffix)`; the Release IntDir
    rewrite in `src/Directory.Build.targets` (KEEP IN SYNC block) uses the same token — output
    `build\tandemcommander\<Config>_x64_portable\` with its own intermediates;
  - `sal_base.props` (imported only by `salamand.vcxproj`) adds `TC_PORTABLE` to `ClCompile` **and**
    `ResourceCompile` definitions when `TcEdition=portable` — only the core executable differs;
  - plug-ins are compiled from the same sources (identical code) into the portable tree.
- `build.cmd` passes `/p:TcEdition=portable`, sets `OUT_DIR` with the suffix (both places it is
  computed, lines ~146 and ~451, and the display lines) and fixes `build_langs.cmd`, which recomputes
  the path itself. `setup\build_setup.cmd` and the `.iss` keep `Release_x64` (they package the normal
  edition only — FR-002).
- **Rationale**: FR-002 (separate trees, neither touches the other), one switch, plug-ins need no
  edition knowledge at compile time (R-07 gives it at run time).
- **Alternatives**: `/p:OPENSAL_BUILD_DIR=<root>portable\` (no project edits, but the path is
  `build\portable\tandemcommander\Release_x64\`, not the clarified `<Config>_x64_portable\`, and the
  installer scripts' hard-coded `..\build\…` would be one wrong variable away from packaging the
  portable tree); building only `salamand.vcxproj` twice and copying plug-ins from the normal tree
  (the portable build would depend on a normal build being present and current). Rejected.
- **Cost**: `dist` compiles the solution twice; acceptable for a release (measured at
  implementation; reported in the closing report).

## R-07 Plug-ins learn the edition at run time — plug-in API 109

- **Decision**: append three methods to `CSalamanderGeneralAbstract`, `LAST_VERSION_OF_SALAMANDER`
  108 → **109**, history entry in `spl_vers.h`, contract
  [contracts/plugin-api-109.md](contracts/plugin-api-109.md):
  `IsPortableEdition()`, `GetUserDataFolderW(kind, buf, size)` (kinds: WebView2 data, the program's
  local data folder) and `GetInstanceScopeSuffix(buf, size)`.
- **Users in this feature**: `src/common/webhost` (`TcWebUserDataFolder()` — the one definition,
  architecture/11 — asks the core when the core is ≥ 109, else today's folder), PictView (the
  previous-wallpaper record into its plug-in configuration in the portable edition), File Comparator
  (its named objects take the scope suffix).
- **Rationale**: the established append path (105-108 were method appends with a bump); a plug-in
  built for 109 checks the core version before calling, so it keeps loading on 108.
- **Alternatives**: a new `SALCFG_*` id for `GetConfigParameter` (ABI-safe without a bump, but no id
  was ever added, strings through it are code page, and it is main-thread-only); an environment
  variable (invisible contract). Rejected.

## R-08 WebView2 data (Q-03 answer)

- **Decision**: in the portable edition `GetUserDataFolderW(SALUSERDATA_WEBVIEW2)` returns
  `<session folder>\WebView2`; everything else of architecture/11 (one folder per program, one
  `TcWebBrowserArguments()`, one options builder) stays. `mdview`'s clean-up of the old
  `mdview.WebView2` folder is skipped in the portable edition.
- **Rationale**: measured 27 MB / 373 files of caches only; nothing the viewers need; the session
  folder is deleted at exit (R-04). `architecture/11-webview2-integration.md` gets the portable rule
  in the same change (it is binding).

## R-09 Other files outside the folder (FR-007, FR-008)

| Item | Decision |
|------|----------|
| Bug reports (`callstk.cpp`) | `settings\BugReports\` (path computed at start-up; the crash handler only formats into it) |
| *Export Configuration* default folder, `config.reg` fallback (`GetOurPathInRoamingAPPDATA`) | default `settings\`; the start-up import of `<exe>\config.reg` / `%APPDATA%\…\config.reg` and `-c <file>` are **ignored** in the portable edition (Q-07 sub-question, recommendation) |
| Backups before a 245 import | `settings\Backups\` |
| Update downloads (`%LOCALAPPDATA%\…\Updates`) | never (no download, FR-017) |
| PictView wallpaper bitmap | stays `%LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp` — Windows' wallpaper must survive the stick (Q-06 recommendation B, the FR-008 exception); its `PrevWallpaper*` record moves into PictView's plug-in configuration |
| Disk cache `SAL*.tmp`, list files, 7za temp in `%TEMP%` | unchanged (transient, cleaned as today) |
| Jump list | not built in the portable edition (Q-04 recommendation) |
| Icon-cache refresh writing `Shell Icon Size` | skipped in the portable edition (Q-04) |
| Restart Manager registration | kept (held by the OS) |

## R-10 Start-up chain in the portable edition

Skipped at compile time (`TC_PORTABLE`): `MigrateConfigurationRoot` (343), `GetUpgradeInfo` /
`AutoImportConfig`, `FindLatestConfiguration`, `DeleteOldConfigurations`, the 245 first-start
offer, the shell-extension registration, the jump list. Added first in `WinMainBody` (before the
language key and `CheckOnlyOneInstance`, which read the configuration): open the store (R-01,
R-04); the global `SalCfgBaseKey` becomes the session hive root. Code reads the configuration
through `SalCfgBaseKey` + `SalamanderConfigurationRoots[0]` — the subkey path inside the hive is the
same `Software\Tandem Commander\Settings`, so the dump text equals an export.

- **Base key**: `SalCfgBaseKey()` is `HKEY_CURRENT_USER` (a constant inline, no behaviour change) in
  the normal edition and the hive root in the portable one; it replaces the literal at the config
  sites (≈ 15 core files: `mainwnd2.cpp`, `plugins1.cpp`, `salamdr2.cpp`, `mainwnd3.cpp`,
  `cfgimport.cpp`, `salamdr1.cpp`, `updcheck.cpp`, `callstk.cpp`, …) and reglib's system registry
  gets the base key for its `HKEY_CURRENT_USER\…` names (export / import inside the portable copy).
  System keys (`drivelst.cpp`, `icncache.cpp`, …) keep `HKEY_CURRENT_USER`. A check script lists
  every remaining literal with its classification (no silent miss).

## R-11 New-version check (Q-13, Q-14, Q-29)

- `salupdcheck.h`: `SalUpdPortableName(ver)` = `tandemcommander-<ver>-x64-portable.zip` and its URL
  builder; `SalUpdParseLatestRelease` takes the edition and requires that asset (exactly once,
  uploaded, URL matches) instead of the installer for the portable edition; saltests.
- `UpdInstall_IsEligible` is FALSE at compile time in the portable edition (no uninstall-entry read);
  the notification shows the link only, with a portable hint ("download the new portable archive");
  Configuration > General hides the level list in the portable edition (today it is gated only by the
  check box — measured).
- State in the session hive (follows the base key), mutex scoped (R-05).

## R-12 Package, `dist`, release

- ZIP by a Python script `tools/portable/make_portable_zip.py` (Python is already required): sorted
  entries, fixed time stamp (the commit time), excludes `*.pdb *.lib *.exp`, intermediates and
  `utils\salext*`; one top folder `TandemCommander-<ver>-portable\`; adds `README-portable.txt`
  (English), the GPL text (`LICENSE`), `doc\third_party.txt` and `doc\license\*` (measured: the
  installer ships none of these in the tree — the ZIP must carry them; 7-Zip is LGPL). Version read
  from `spl_vers.h`.
- `build.cmd dist` = `full release rebuild sign setup` then `full release rebuild sign portable`,
  refuses other arguments and a missing `tools\codesign\codesign.cfg`, stops at the first failure,
  prints both files with size and SHA-256 (`certutil -hashfile` or Python).
- `backlog/RELEASE.md`: step 2 becomes `build.cmd dist`, step 5 attaches both files; *Release
  records* unchanged in number (the ZIP is an artefact, not a record); `tools/release/release.py`
  gets an artefact check (both files of the version in `setup\output\`) used by `/tandem-release`'s
  closing checklist.

## R-13 Identity (Q-19, Q-20, Q-21, Q-22, Q-23)

- Title: `" [portable]"` appended in `CMainWindow::SetWindowTitle` before `" (Administrator)"`, a
  literal (not a string resource).
- About: two controls created at run time in `CAboutDialog` (portable only) below the version — a
  static with `IDS_ABOUT_PORTABLE_EDITION` and a link (the existing `CUpdateLink` style) with the
  `settings` path; the dialog grows by their height; no dialog template changes (no layout work in
  eight languages).
- Icon: `IDI_SALAMANDER` comes from `res\salamand_portable.ico` under `TC_PORTABLE` (rc define);
  the badge is generated from the brand sources by a script in `tools/brand/` (all sizes of
  `salamand.ico`), checked in.
- Taskbar: **no AppUserModelID is set** — measured that the program sets none and the installer's
  shortcut has none; Windows then groups by the executable path, so the portable copy is already a
  separate group with its own pin (verified by a probe, not assumed).
- Version resource: `FileDescription` "Tandem Commander (portable)" under `TC_PORTABLE`;
  ProductName and versions unchanged.

## R-14 Verification approach

- saltests: `salportable.h` (scope id, session names, relativize / expand incl. adversarial paths:
  case, trailing backslash, prefix of a longer name `E:\TC2`, UNC, `\\?\`, non-BMP), `salupdcheck.h`
  portable asset, store start decision table (pure: held / stale / absent × file ok / bad / missing /
  unreadable).
- Gate test before wiring the core: **lossless round trip** of the real configuration hive → dump →
  parse into a new hive → recursive compare (every key, value, type, byte), plus synthetic values
  (all types, empty, 1 MB binary, names with 255 characters and non-BMP letters). reglib was made
  Unicode-clean in 174; anything lost is fixed in reglib inside this feature.
- Probes on the hidden desktop (`specs/428-portable-build/probe/`), product key backed up and
  restored: registry snapshot diff (HKCU / HKLM-readable / HKCR minus a documented list of keys
  Windows itself changes) and profile-folder diff for SC-002; move with `subst` (SC-003); read-only
  folder via a deny ACE (US6); kill during a save (SC-006); installed + portable side by side
  (SC-007); update fixture (US5); the shell-extension message; the password note; `dist` on a clean
  checkout (SC-005a).
- Owed to a person (release checklist): a real FAT32 / exFAT USB stick on two PCs with different
  drive letters, SmartScreen on a downloaded ZIP, the badge icon on a real taskbar in both themes.
