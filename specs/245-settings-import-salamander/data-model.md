# Data model — feature 245

All in memory, alive only while the wizard runs. Strings UTF-8 (WTF-8).

## CSalCfgKey / CSalCfgValue (snapshot, `salcfgimport.h`)

Tree copy of the source root: `Name`, values (`Name`, `Type`, `Data`, `Size`;
`REG_SZ`/`REG_EXPAND_SZ` converted from UTF-16 to UTF-8 and NUL-terminated,
`REG_DWORD` 4 bytes, others verbatim), subkeys. Built by the reader
(`cfgimport.cpp`) within limits (research R1); a limit hit marks the
snapshot *truncated* (the affected group reports it, nothing is guessed).
Freed when the wizard ends.

## CCfgImpSource (`cfgimport.h`)

| Field | Meaning |
|---|---|
| `KeyPath` | HKCU-relative root, e.g. `Software\Altap\Altap Salamander 4.0` |
| `ProductName` | label shown to the user |
| `ConfigVersion` | `Version\Configuration` (1/2 rules of `LoadConfig`) |
| `Support` | supported / too old / too new |
| `SaveInProgress` | the root carries `Save In Progress` |
| `TableOrder` | position in the root table (tie-break) |

Discovery returns them sorted newest first.

## CCfgImpGroup

| Field | Meaning |
|---|---|
| `Id` | `hotpaths`, `usermenu`, `ftp`, `pluginkeys`, `viewers`, `findsets`, `histories`, `confirmations`, `panelopts`, `general`, `viewer`, `colors`, `templates`, `defaultdirs`, `plugin:<key>` |
| `Kind` | list / options |
| `ModesAllowed` | Add, Replace, TakeOver |
| `Selected`, `Mode` | the user's choice (defaults: research R4) |
| `ItemCount` | items in the source (0 ⇒ unavailable "empty") |
| `Availability` + `Reason` | available / empty / not transferable (text) |
| `PluginIndex` | for `ftp` and `plugin:<key>`: TC's plugin index (−1 when not shipped) |

State: *unselected* → *selected (mode)* → *planned* (preview lines) →
*applied* / *failed (reason)*.

## CCfgImpLine (preview and result)

`GroupId`, `Kind` (ADDED, PRESENT, REPLACED, REMOVED, SKIPPED, FLAGGED,
NOTE — the same set as `SALIMPORT_REPORT_*`), `Text` (one item, with the
reason for SKIPPED/FLAGGED, "current → new" for REPLACED). A plan *needs
consent* when any line is REPLACED or REMOVED.

## CCfgImpPlan

The selected groups with their lines plus the computed new content per group
(the object that apply swaps in): hot-path slots [30], user-menu item list,
viewer/alt-viewer/editor lists, plugin hot-key assignments
(plugin index, item index, key), history arrays, option assignments (table
row, new value), colours/highlighting/templates/default directories,
plugin subtrees to copy. FTP's part is planned and applied by the FTP plugin
(interface 108); the core keeps only its report lines.

## CCfgImpPasswords

`SourceUsesMasterPassword`, `SourceVerifier` (42 bytes) from the source's
`Password Manager`; `SourceMasterPassword` (code-page bytes, wiped at the
end); `Policy` (`SALIMPORT_PWD_*`); `AllowWeakerStorage` (consent of page 3);
counts of scrambled / protected blobs in the FTP subtree.

## CCfgImpRun (one wizard run)

Sources, chosen source, snapshot, groups, passwords, plan, backup file
path, result lines, flags *automation* (R18) / *offer* (R13).

## Persistent effects

- TC configuration (through `SaveConfig` and, for `plugin:<key>`, the
  replaced `Plugins Configuration\<key>` subtree while the plugin is
  unloaded).
- Backup file `%APPDATA%\Tandem Commander\Settings backups\before-import-*.reg`.
- Nothing else; in particular nothing in any source root (SC-002).
