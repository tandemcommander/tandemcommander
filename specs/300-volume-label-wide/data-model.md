# Data model - 300-volume-label-wide

No stored data changes. The values at the site:

| Value | Form before the call | Form given to Windows |
|-------|----------------------|-----------------------|
| `newName` - the typed label | UTF-8 / WTF-8, `char[MAX_PATH]`, measured whole first (270) | UTF-16 (`SalU8ToWAlloc`), freed after the call |
| `volumePathWithBackslash` - drive root or mounted folder + `\` | UTF-8, `char[MAX_PATH]` | UTF-16 (`SalU8ToWAlloc`), freed after the call |
| `OldVolumeName` - the label as shown at opening | UTF-8 | unchanged: only compared with `newName` (069) |

State: Validate → (too long? refuse, 270) → (unchanged? nothing) → (either conversion fails?
message, `ErrorOn`, nothing written) → hands-off → `SetVolumeLabelW` → hands-off ends → (failed?
message, `ErrorOn`).
