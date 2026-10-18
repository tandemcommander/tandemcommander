# Research — feature 245 (import settings from Altap / Open Salamander)

Builds on [analysis.md](analysis.md) (inventory with file:line evidence) and
feature 057's research (`specs/057-altap-settings-migration/research.md`).
Each decision: **Decision / Rationale / Alternatives**.

## R1. The wizard lives in the core, reads the source into a snapshot

**Decision**: the core gets an import engine (`src/cfgimport.cpp`) and a
wizard (`src/cfgimpdlg.cpp`). The chosen source root is opened **once** with
`RegOpenKeyExW(..., KEY_READ)` and its relevant subtrees are copied into an
in-memory *snapshot* (`CSalCfgTree`, a key/value tree, strings already UTF-8,
binary values verbatim) with hard limits (depth 6, 4 096 values per key, 64 KiB
per value, 32 MiB total). The source handle is closed right after; everything
else (counting, planning, preview, apply) works on the snapshot.

**Rationale**: FR-005/FR-006 — the program's own registry helpers
(`OpenKey`/`GetValue`, `regwork.cpp`) show a modal box on a wrongly typed or
oversized value and go through the registry worker thread; the section
loaders also read the global `Configuration.ConfigVersion`. A private wide
reader with `KEY_READ` cannot write (the OS refuses writes through a read
handle) and cannot show boxes. A snapshot makes the planning logic pure and
testable in `saltests` (fixtures are built in memory) and guarantees that the
source is touched exactly once per run (SC-002).

**Alternatives**: reuse `LoadConfig`'s section loaders on the foreign key
with a "quiet" flag and a temporary `ConfigVersion` (rejected: global state,
loaders are inline in `LoadConfig` for half the groups, `ConfigVersion` is read
by other code while the wizard runs); revive the upstream start-up import
(rejected: replaces everything, can delete the source, analysis § A9).

## R2. Supported sources and their discovery

**Decision**: a fixed table in `salcfgimport.h` built from the upstream root
list (`git show afcaa9eb -- src/mainwnd2.cpp`): `Software\Open
Salamander\5.0`, then `Software\Altap\Altap Salamander 4.0` down to the 2.5x
roots, then the Servant Salamander roots. A root qualifies when it has a
`Configuration` subkey. Its `Version\Configuration` DWORD (missing key ⇒ 1,
missing value ⇒ 2) classifies it: **< 39** (before Altap Salamander 2.5) and
**> 106** (newer than this program) are listed *not supported*; 39–106 are
supported. Newest first by configuration version, ties by table order.
Product label = the root's last component (e.g. "Altap Salamander 4.0").
`Newt Commander` and `Tandem Commander` roots are never sources.
A test seam (`_DEBUG` builds only): the environment variable
`TC_CFGIMPORT_TEST_ROOT=<HKCU-relative key>` replaces the table by the
subkeys of that key, so probes never need the real Altap/Open Salamander
keys.

**Rationale**: FR-003/FR-004; 057 R2/R3 (the only conversions needed from 39
on are R6's two). The fork-era `Open Salamander\5.0` (version 105) is accepted
as it is ≤ 106 and has the same layout.

## R3. Version conversions applied while parsing

**Decision**: for sources with configuration < 47 double every `$` in
hot-path paths (`DuplicateDollars` semantics); for < 44 lower-case the masks of
viewers/alternative viewers/editors (`StrICpy` semantics). Nothing else: all
other gates are < 39 or concern groups that are never imported (packers < 105,
archivers < 106). The source's `Version` is never copied; TC's configuration
version stays 106 (no start-up upgrade is triggered, analysis § A1).

## R4. Groups, kinds and defaults (FR-008, FR-009, FR-010c)

| Id | Group | Kind | Modes | Default |
|---|---|---|---|---|
| `hotpaths` | Hot paths | list | Add / Replace | ticked, Add |
| `usermenu` | User menu | list | Add / Replace | ticked, Add |
| `ftp` | FTP connections (bookmarks, proxy servers, server types) | list via plugin | Add / Replace | ticked, Add |
| `pluginkeys` | Plugin command shortcuts | list | Add / Replace | ticked, Add |
| `viewers` | Viewers, alternative viewers, editors | list | Add | ticked, Add |
| `findsets` | Saved search criteria and the search ignore list | list | Add | ticked, Add |
| `histories` | Histories (paths, commands, masks) | list | Add | unticked |
| `confirmations` | Confirmations | options | take over | unticked |
| `panelopts` | Panel and keyboard behaviour | options | take over | unticked |
| `general` | General options | options | take over | unticked |
| `viewer` | Internal viewer settings | options | take over | unticked |
| `colors` | Colours and panel item highlighting | options | take over | unticked |
| `templates` | View templates (columns) | options | take over | unticked |
| `defaultdirs` | Per-drive default directories | options | take over | unticked |
| `plugin:<key>` | Settings of plugin *X* (one row per shipped plugin present in the source, FTP excluded) | options | take over | unticked |

Every row whose mode overwrites (Replace, take over) is unticked by default
and, when ticked, is listed value by value in the preview, which then needs
the consent tick (FR-010c). With the defaults the wizard only adds.
Toolbar layouts are **not** offered (R14).

## R5. Merge identities and conflict rules (FR-010, FR-012)

- **Hot path**: identity = path compared with `SalPathEqualOrdinalCI` after
  removing a trailing backslash (not for roots). Duplicate ⇒ "already
  present". Placement: the source slot when free, else the first free slot
  (1–30); the result says when the slot (and so the Ctrl+digit key) differs;
  no free slot ⇒ skipped. Replace: the 30 slots become the source's slots.
  Names follow 047 (a stored name equal to the path text = unnamed).
- **User menu item**: identity = (type, name, command, arguments, initial
  directory) — exact byte compare (these are user-typed texts); separators
  never count as duplicates. Add appends the source items **as a block at the
  end**, keeping submenu structure; a top-level item identical to an existing
  top-level item is skipped together with its submenu content when the
  submenu is identical; a submenu-begin whose content differs is appended
  whole. Replace: the menu becomes the source's.
- **Viewer / alternative viewer / editor**: identity = the masks string
  normalised (split at `;`, trim, lower-case ASCII, empty parts dropped,
  sorted, joined). An imported row whose normalised masks equal an existing
  row's is "already covered". New rows are appended **after** the current ones
  (current rows keep precedence). A row whose masks contain `|` is skipped
  (TC's own loader refuses it). Plugin rows (type < 0) are re-mapped (R7).
- **Plugin command shortcut**: identity = (plugin DLL, menu item ID). Only
  user-assigned keys (`HOTKEY_DIRTY`) are imported. Add: assign only when the
  TC item has no user-assigned key and the key is used neither by a TC command
  (`IsSalHotKey`) nor by another plugin item. Replace: the imported key wins
  over a current *plugin* assignment (that assignment is removed, reported),
  never over a TC command.
- **History entry**: identity = exact text; current entries first, then
  imported ones not present, up to the history's capacity; passwords are
  stripped with `SalStripUrlPasswords` / `SalStripCommandLinePasswords` before
  comparing (FR-021).
- **Saved search criteria**: identity = the item name (`ItemName`); duplicate
  names ⇒ skipped "already present". **Ignore list**: identity = the path
  (`SalPathEqualOrdinalCI`).
- **FTP bookmark**: R9.

## R6. Applying while the program runs (FR-025, FR-026)

**Decision**: groups are applied to the **in-memory objects** of the running
program in this order: core lists, options, plugin shortcuts, plugin
settings, FTP; then the post-configuration refresh that the Configuration
dialog performs (factored out of `WM_USER_CONFIGURATION` into
`CMainWindow::RefreshAfterConfiguration(const CCfgRefreshState&)`, used by
both), then one `SaveConfig()`. Each group is applied all-or-nothing: the new
content is built completely first (copy of the current list + changes) and
swapped in only when complete; a failure leaves the group as it was and is
reported.

**Rationale**: the program rewrites its whole configuration from memory on
exit (and every other instance on its exit), so a registry-only import would
be lost (analysis § A9); the Configuration dialog's path is the proven
runtime model. `SaveConfig()` at the end makes the import durable even with
*Save configuration on exit* off.

## R7. Plugin references are re-mapped by DLL, never by position

**Decision**: viewer rows with type < 0 refer to `-(index+1)` in the source's
`Plugins\1..N` order. The source's `Plugins\<n>\DLL` gives the DLL; it is
compared with TC's plugins by the relative DLL path (`ftp\ftp.spl`), or for
absolute source paths by its last two components, case-insensitively. A
match yields TC's index; otherwise the row is skipped ("plugin X is not part
of Tandem Commander"). The same mapping serves plugin shortcuts and plugin
settings (by `Configuration Key` cross-checked with the DLL).

## R8. Plugin settings ("take over" for a whole plugin)

**Decision**: for a shipped plugin with configuration in the source (ZIP,
7zip, Checksum, DBVIEWER, DISKMAP, File Comparator, PEVIEWER, PictView,
RegEdit, Renamer, UnCAB, UNDELETE, UnISO; TAR is not offered — it stores only
its schema version), the wizard **unloads the plugin** (`CPluginData::Unload`,
which first saves its current settings), then replaces TC's
`Plugins Configuration\<key>` subtree with the snapshot's subtree (including
the plugin's own `Version` value, which drives the plugin's internal
upgrade, e.g. 7zip 3 → 5). The plugin loads the new settings the next time it
is used. A plugin that cannot be unloaded (open windows, busy) fails that
group with "close the plugin's windows and try again". Nothing is written for
plugins that are not shipped; TC-only plugins are never touched. The
`Plugins` / `Plugins Order` registration and the `plugins.ver` counters are
never written.

**Rationale**: unloaded plugins' keys are not rewritten by `SaveConfig`
(`plugins2.cpp:1750`) — the replaced key survives; the plugin's own loader
does the format work. Writing TC's key while TC runs is safe here precisely
because the plugin is unloaded.

**Alternatives**: reload the plugin with `LoadConfiguration` pointed at the
source key (rejected: needs an `InitDLL` override and gains nothing over the
copy; the copy is what the plugin would read anyway).

## R9. FTP connections through plugin interface 108

**Decision**: interface 108 appends to `CSalamanderPluginEntryAbstract`
`SetPluginSettingsImport(CPluginSettingsImportAbstract*)` (a plugin registers
an import handler during entry) and defines two new classes:
`CPluginSettingsImportAbstract` (implemented by the plugin: `Plan`, `Apply`)
and `CSalamanderSettingsImportAbstract` (implemented by the core, handed to
the handler: mode, source description, the plugin's source key **read-only**
as a registry handle into an in-memory copy, report sink, password
services). Contract: `contracts/plugin-api-v108.md`. The FTP plugin:
- loads the source `Bookmarks`, `Proxy Servers`, `Server Types` into
  temporary lists with its own loaders;
- **Add**: proxy servers — an identical one (name, type, host, port, user)
  is reused, otherwise added with a new UID and a unique name; bookmarks —
  identical (address, port, user, initial path, server type, proxy) ⇒
  "already present"; same name, other content ⇒ added as "Name (imported)",
  "(imported 2)" …; user-defined server types not present by name are added;
  proxy UIDs of imported bookmarks are re-mapped;
- **Replace**: the three lists become the source's (proxy UIDs re-mapped to
  the new list, bookmarks referring to missing proxies fall back to default);
- passwords: R10. `Plan` computes the same result without changing anything.

**Rationale**: the clarification (Q3) chose an append-only call; registering
through the core-implemented entry object is a pure vtable append (as 105–107
were), so plugins built for 104–107 keep loading.

## R10. Passwords (FR-018 … FR-020)

**Decision**:
- *Scrambled* blobs (signature 1) are decrypted with the normal
  `DecryptPassword` (needs no master password) and re-stored as TC stores
  passwords: AES under TC's master password if TC uses one (the user is asked
  for it once, via `AskForMasterPassword`, before apply), else scrambled.
- *AES* blobs (signature 2) need the source master password: the wizard's
  password page appears only when the selected FTP import contains such
  blobs. The typed password (code-page bytes, like the old program's dialog)
  is checked against the source's `Password Manager\Master Password
  Verifier` (same algorithm as `VerifyMasterPassword`, new static helper);
  wrong ⇒ retry or skip. The core decrypts on the handler's request
  (`DecryptSourcePassword`); the plugin re-protects. If TC has no master
  password, AES-protected passwords would become scrambled: the page shows a
  separate consent tick ("store them without a master password"); without it
  they are not imported (connection imported without password, reported).
- TC's `Password Manager` values are never written by the import.

## R11. Backup and restore (FR-023)

**Decision**: before the first change, if TC's root does not exist yet,
`SaveConfig()` first; then `ExportConfiguration(parent, file, TRUE)` (feature
174; the `.reg` starts by deleting the key, so importing it restores exactly)
to `%APPDATA%\Tandem Commander\Settings backups\before-import-YYYYMMDD-HHMMSS.reg`
(created with the program's file services; a name collision gets `-2`, `-3`).
Failure ⇒ nothing is changed. The result page shows the file and the restore
steps: close Tandem Commander, start it with `-C "<file>"` (the existing
start-up import), or double-click the file.

## R12. Other instances and the source program (FR-024)

**Decision**: refuse while `TaskList.GetItems` lists another Tandem Commander
process (PID ≠ own), checked when the wizard opens and again right before
apply. A running old program (`salamand.exe` found by a Toolhelp snapshot)
only adds a note to the source page. A source root carrying `Save In
Progress` is offered with a warning.

## R13. First-start offer (FR-002)

**Decision**: in `WinMainBody`, before `LoadConfig`, `freshConfig` = TC's
root has no `Configuration` subkey (after a possible `config.reg`/`-C`
import). After the main window is shown and the start-up dialogs are done,
if `freshConfig` and at least one *supported* source root exists
(existence check only: opening `<root>\Configuration` and reading
`Version\Configuration` to classify it — no settings are read), the main
window posts itself `WM_USER_CFGIMPORT_OFFER`; the handler shows a box
*Import now* / *Not now* stating that the command stays in the Options menu.
Either answer, or closing the box, calls `SaveConfig()` so the configuration
exists and the offer never comes back (FR-002). Not shown in the automation
seam or when another instance runs.

**Note**: reading `Version\Configuration` is the minimum needed to say
"supported" (an unsupported old root would make the offer lead nowhere); it is
classification, not settings, and is stated so in the constitution note.

## R14. Toolbar layouts are not offered

**Decision**: not offered. The button table is unchanged since upstream
(analysis § A6), but the layouts reference buttons by number and TC's
defaults differ (theme, tabs, command shell commands exist as menu commands
only), a layout copied over would remove buttons users of TC know from its
defaults, and the value to a migrating user is low. Recorded as *not
transferable by design* in the group list's footnote.

## R15. Options groups: an allow-list table

**Decision**: the option groups (`confirmations`, `panelopts`, `general`,
`viewer`, `defaultdirs`) are driven by a table in `cfgimport.cpp`: registry
subkey, value name, kind (DWORD bool, DWORD range [min,max], string with max
length and validator), address of the in-memory field, group. Only values on
the table are ever imported; a source value with a wrong type or out of range
is skipped and reported. TC-owned values (FR-016: `Theme Mode`, `Panel Tabs`,
`Quick Search Filter`, `Command Shell *`, language values, `Plugins.ver *`,
icon overlay lists, window/dialog geometry, `Main window icon index`,
`Conversion Table`, `Only One Instance`, `Last Focused Page`, `Configuration
Height`, `* Expanded`, `Skill Level`, toolbar layouts, `Save Configuration on
Exit`) are **absent from the table** by construction, and a `saltests` check
asserts the table contains none of them (the forbidden list lives in the pure
header). Default directories use 057's filter F2 (single letter A–Z, value
`X:\…` of that letter, longer than 3 characters).

**Rationale**: an allow-list is the only way to make FR-016 provable; 057's
exclude-list let unknown values through (which is how it overwrote TC
settings — the maintainer's directive).

## R16. Colours, highlighting, view templates, search criteria

**Decision**: parsed from the snapshot by small readers mirroring
`LoadConfig`'s code: `Custom Colors` (16 × `LoadRGB` format), `Colors` (scheme
id remapped as `LoadConfig` does, `UserColors` via the `LoadRGBF` format,
`Panel Items Hilighting` list → `HighlightMasks`), `View Templates\0..9` (the
`CViewTemplates::Load` value set), `Find Options` items and `Find Ignore`
items (their `Load` value sets). Applying swaps the global objects as the
Configuration dialog does and calls `UpdateCurrentColorsForTheme()`; the
dark theme stays (FR-016).

## R17. Wizard UI

**Decision**: five modal pages (each a `DIALOGEX` with `DS_SHELLFONT`, `FONT 8,
"MS Shell Dlg"`, themed controls, `CCommonDialog` base so the dark theme
applies): *Source*, *What to import* (list view with check boxes, columns
group / items / mode, mode radio buttons for the selected row, a note that
TC's own command shortcuts are fixed), *Passwords* (only when needed),
*Preview* (read-only multi-line text + consent check box shown only when
something will be overwritten or removed; *Import* disabled until ticked),
*Result* (read-only text, *Copy*, *Save…*, *Close*). *Back* / *Next* /
*Cancel* / *Help* on every page; Esc = Cancel before the confirmation.
Texts are built as UTF-8 and shown through the wide helpers.

## R18. Automation seam for end-to-end tests

**Decision**: `_DEBUG` builds only: environment variable
`TC_CFGIMPORT_AUTORUN=<file>` makes the main window, once it is idle, run the
wizard without UI from a small INI-style script (source index, groups with
modes, consent flags, optional source master password), write the preview and
the result to `<file>.preview.txt` / `<file>.result.txt` and close the program
(normal exit, so the exit save is exercised too). Never compiled into
Release.

**Rationale**: SC-002…SC-010 need many repeatable runs over fixtures with
exact before/after registry comparisons; driving five dialogs for each is
slow and flaky on the hidden desktop. The UI itself is covered by a separate,
smaller probe.

## R19. Retiring the 057 script (FR-032)

**Decision**: remove `utils/migrate-altap-settings.cmd`, `utils/test/` and
`utils/README.md`'s description (the folder goes if empty); the changelog
entry and the README section that mentioned the script point to *Options →
Import Settings from Salamander…*. 057's records stay.

## R20. Documents in the same change (FR-031)

Constitution II amended (3.2.0 → 4.0.0: a principle redefined — MAJOR per the
versioning policy; Sync Impact Report), `CLAUDE.md` product identity line,
`architecture/12-project-reference.md`, `architecture/06` (interface 108),
`PRIVACY.md` (*Settings and history*, *Saved passwords*, validity line
unchanged — set on release), `README.md`, `CHANGELOG.md` (unreleased),
help page, `specs/FEATURE-HISTORY.md`, `backlog` Inbox items for analysis
§ A11.
