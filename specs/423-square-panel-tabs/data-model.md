# Data model - 423

## Tab style (`Configuration.PanelTabStyle`, int)

| Stored `Panel Tab Style` | In memory | Effective style (`SalTabStyleFromStored`) |
|---|---|---|
| missing | 0 | Square |
| REG_DWORD 0 | 0 | Square |
| REG_DWORD 1 | 1 | Rounded |
| REG_DWORD any other n | n (kept) | Square |
| wrong type (REG_SZ, ...) | 0 | Square |

- Written with the configuration (`SaveConfig`) as read; the Appearance page changes it only when
  the user picks the other style.
- Default of a fresh configuration (`CConfiguration` constructor): 0 (Square).
- One value for the program (both panels).

## Strip colours (`CSalTabStripColors`)

| Field | Light (before -> after) | Dark | High Contrast |
|---|---|---|---|
| DimText | mix(text, StripBk, 0.38) -> mix(text, StripBk, 0.20) | unchanged (0.30) | unchanged (text) |
| everything else | unchanged | unchanged | unchanged |
