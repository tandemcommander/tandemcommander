# Data model - 274

No stored data changes. The values the fix works with:

- **Typed text** - UTF-8, up to `SAL_MAX_PATH_UTF8 - 1` bytes (the dialog's buffer); relative
  ("nd", "a\b") or absolute.
- **Full path** - the typed text joined with the panel path; valid when it is shorter than
  `SAL_MAX_PATH_UTF8` bytes, else refused "The path specified is too long.".
- **New folder name** - the last component of the full path; valid when it has at most 255
  UTF-16 units, else refused "Cannot finish operation because of too long name.".
