# Data model: 290

- **Member name** - a central header's name as `ProcessName` returns it: UTF-8, `\` separated, no
  leading separator, folders may end with `\`. The same form the listing builds its tree from.
- **Path prefix** - a member name up to (not including) one of its separators, or the whole name if
  it does not end with a separator. A `SalCaseTwinName` pointing into the collected names.
- **Archive has twins** (bool, per add) - `SalPathsHaveCaseTwins` over all prefixes of all member
  names. TRUE switches the match to exact (`pathFlag = 0`, `nameIgnoreCase = FALSE`).
- **Added item** (`CAddInfo`) - unchanged; its `Action` transitions (AF_ADD -> AF_NOADD / AF_DEL /
  AF_OVERWRITE) are unchanged, only fewer members match it in a twin archive.
