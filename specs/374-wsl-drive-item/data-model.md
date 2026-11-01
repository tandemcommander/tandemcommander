# Data model - 374-wsl-drive-item

## WSL distribution (read only)

| Field | Source | Rule |
|---|---|---|
| name | `DistributionName` (REG_SZ) of a subkey of `HKCU\...\Lxss` | usable: 1..`SAL_WSL_NAME_MAX` (255) characters, none of `\ / : * ? " < > |`, no control character (< 0x20), not `.` / `..`; kept as UTF-8 (WTF-8) |
| state | `State` (DWORD), optional | listed when absent or 1 |

List: sorted by `SalNameOrderCompareCI`, case-insensitive duplicates dropped (the first kept).

Path: `\\wsl.localhost\<name>` (UTF-8); refused (item left out / not opened) when it does not fit
`SAL_MAX_PATH_UTF8` - never cut.

"Path is on distribution d": the path starts with `\\wsl.localhost\` or `\\wsl$\` (ASCII case
ignored), followed by d (the file system's name equality), followed by end or `\`.

Fingerprint: FNV-1a over the sorted names (each followed by a 0 byte), folded to 24 bits.

## Drive list items (new)

| Type | Number | Text | Param | Where |
|---|---|---|---|---|
| `drvtWSL` | 19 | `\tLinux - <name>` | index into the list | menu: one per name; bar: when exactly one name |
| `drvtWSLMenu` | 20 | `\tLinux` | 0 | bar only, when more than one name |

## Configuration

| Member | Registry value (`...\Settings\Configuration`) | Default |
|---|---|---|
| `ChangeDriveShowWSL` | `Change Drive Show WSL` (DWORD 0/1) | 1 |
