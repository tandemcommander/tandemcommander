# Data model - feature 284

No stored data. Two values:

- **Share root path** - a disk path of the panel, `\\server\share` or `\\server\share\`
  (backslashes only); `server` not empty, not `.` or `?`; `share` not empty; nothing after it.
- **Server path** - `\\server\` derived from it; handed to the panel's path change, which offers
  the server's shares (feature 125). Refused, never cut, when it does not fit the caller's buffer.

The rule between them: [contracts/share-root-rule.md](contracts/share-root-rule.md).
