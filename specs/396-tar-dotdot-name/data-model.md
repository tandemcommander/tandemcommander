# Data model - 396-tar-dotdot-name

## Member name (as read from the archive)

A byte string (UTF-8 after `ConvertNameToU8`), components separated by `/` or `\`.

## Normalized name (output of `SalTarNormalizeNameU8`)

- Components separated by exactly one `\`; no leading `\`; a trailing `\` when the source ended with
  a separator after a component (the caller's "folder" mark).
- `.` components dropped.
- `..` component: removes the last component of the output so far; on an empty output it is
  dropped (never above the root).
- Any other component copied byte for byte (`..a`, `...`, `a..b`, UTF-8 bytes).
- Length <= source length; always terminated.
- Empty output = "a name that normalizes to nothing" (the caller's existing branch, 394 / 395).
