# Contract: probe seam `TC_PROBE_DRIVES_DUMP` - amendment of feature 289

Base contract: `specs/246-network-drive-labels/contracts/probe-seam.md` (Debug builds only,
one UTF-8 line + CRLF per event, the variable read on every call, behaviour unchanged).

Feature 289 adds / changes:

| Line | When | Fields |
|---|---|---|
| `TYPES folder=<FolderTypeName> updir=<UpDirTypeName>` | right after each `BUILD` line | the two type names of the panel's *Type* column, verbatim bytes |
| `TIP <letter> <text>` | `GetDriveBarToolTip` for **every** drive item (was: network drives only); recorded once at the end of the function with the text as answered | `<letter>` = first byte of `DriveText` |

`ProbeDumpToolTips` (after a drive bar `BUILD`) asks the tooltip of every item that is not a
separator (was: `drvtRemote` only). It runs only when the variable is set.

The seam writes the program's bytes as they are; a probe checks them with a strict UTF-8
decoder. Release builds contain none of it.
