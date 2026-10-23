# Data model - 317-pack-name-space

No stored data, settings or structures change.

The one value involved: the **archive name** of the Pack dialog (`fileBuf`, `MAX_PATH` bytes,
UTF-8) - relative (joined with the panel's path) or absolute. After this feature a relative name
keeps its leading spaces when it is joined; absolute names, names starting with `\` after spaces,
drive-relative names and an empty entry are treated as before (research R2).
