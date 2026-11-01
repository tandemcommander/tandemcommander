# Research - 374-wsl-drive-item

## R1 Where the list of distributions comes from

- **Decision**: the per-user registry key `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss`,
  one subkey per distribution, value `DistributionName` (REG_SZ), optional `State` (DWORD,
  1 = installed; 3 installing, 4 uninstalling).
- **Rationale**: reading the registry starts nothing (measured: no distribution running before
  or after); a few milliseconds. It is the store WSL itself keeps (`wsl -l` reads it through the
  service).
- **Alternatives**: `WNetOpenEnumW` on `\\wsl.localhost` (373) - asks the Plan 9 provider,
  which talks to the WSL service (may start it); `wsl.exe -l` - runs a process, output in
  UTF-16 with a console code page, starts the service; the WSL API (`wslapi.dll`
  `WslIsDistributionRegistered`) - needs a name to ask about, cannot list.

## R2 Icon

- **Decision**: icon 0 of `<GetSystemDirectoryW>\wsl.exe` through `SHDefExtractIconW` at the
  16 px DPI size; when it fails, the Network icon (`ImageResDLL` 152).
- **Rationale**: the Tux icon is what File Explorer shows for the *Linux* node; reading an icon
  resource maps the file as data, it does not run it. Measured: `System32\wsl.exe` icon 0 = Tux.
- **Alternatives**: a new icon in the program's resources (no brand asset exists; a penguin
  drawn here would be ours to maintain); the shell's icon for `\\wsl.localhost`
  (`SHGetFileInfo` - goes to the network provider, may start WSL).

## R3 Item types and probe numbers

- **Decision**: `drvtWSL`, `drvtWSLMenu` appended after `drvtPluginFSInOtherPanel` (19, 20).
- **Rationale**: `run289.ps1` takes types 1..14 for its ALL rows and 7 / 13 / 14 by number; the
  copy test `DriveType > drvtRAMDisk` of `BuildData` stays true for the new types.

## R4 How the item carries its distribution

- **Decision**: the names live in a list member of `CDrivesList`; an item's `Param` is the index;
  `ExecuteItem` hands a `DupStr` copy out through `DriveTypeParam` (freed by the executor, as for
  `drvtOneDriveBus`).
- **Alternatives**: parse the name back out of the item text (the OneDrive Business way) -
  depends on the translated label and the `\t` layout; rejected.

## R5 Settings import

- **Decision**: not on the import allow-list (see spec *Assumptions*): rule 245 FR-016.

## R6 Drive bar refresh

- **Decision**: fold `0x20 | (fingerprint << 8)` into the cloud storages mask (`SalWslFingerprint`
  over the sorted names, FNV-1a 24 bit). The mask is compared when Alt+F1 opens; a change of
  the set of distributions rebuilds the bars as a cloud storage change does.
