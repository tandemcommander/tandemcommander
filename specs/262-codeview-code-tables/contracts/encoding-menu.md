# Contract - Code Viewer Encoding menu and remembered table (262)

Internal to the codeview plug-in; no plug-in interface, core or string change.

## Menu

`View > Encoding`:

1. `UTF-8`, `UTF-8 with BOM`, `UTF-16 LE`, `UTF-16 BE`, `System code page` - ids 4000..4004,
   behaviour unchanged.
2. When at least one table exists: a separator, then the entries of `EnumConversionTables` in its
   order - a NULL name becomes a separator (a leading / doubled separator is not repeated), a name
   becomes an item `4005 + tableIndex` with the name as handed out (hot-key `&` kept).
3. Exactly one item is checked: the table that decoded the open file, else the encoding.

## Keys

F8 / Shift+F8: next / previous position of `0 .. 4+T`, wrapping; separators are not positions.

## Status bar

The encoding field shows `UTF-8`, `UTF-8 BOM`, `UTF-16 LE`, `UTF-16 BE`, `ANSI` as today, or the
table's display name (no single `&`, `&&` -> `&`, trailing spaces trimmed).

## Settings

`DefaultConvert` (REG_SZ, UTF-8) in the codeview key: the remembered table name or empty. Read at
`LoadConfiguration`, written at `SaveConfiguration`. A value that does not match a handed-out name
byte for byte (after the UTF-8 -> code page conversion) means "system code page".
