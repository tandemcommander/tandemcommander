# Data model - 278-regedt-find-regexp-cp

Nothing is stored. One transient value:

- **Prepared text** - the code-page bytes of one key name, value name or text value
  (REG_SZ / REG_EXPAND_SZ / REG_MULTI_SZ without its trailing NULs, feature 189) and their
  count. Lives in `CFindThread::AsciiBuffer` (reused, only grows) for the duration of one
  `Test` call. Rule: count = the code page's byte count of the text; the bytes searched are
  exactly `[0, count)`; a text that cannot be converted has no prepared form (no match).
