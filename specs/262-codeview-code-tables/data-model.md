# Data model - 262

## Conversion table (from `EnumConversionTables`)

| Field | Meaning |
|---|---|
| Name | code-page bytes, may contain `&` (hot-key) and a trailing space (excluded from recognition); NULL = separator |
| Table | 256 bytes, `out = Table[(unsigned char)in]`; valid for the program's life |

Per viewer window: `std::vector<CvCodeTable>` in the enumeration order, separators kept for the menu;
"table index" = position among the non-separator entries (0..T-1).

## Encoding list position (menu / F8)

| Position | Entry | Command id |
|---|---|---|
| 0..4 | UTF-8, UTF-8 with BOM, UTF-16 LE, UTF-16 BE, System code page | 4000..4004 (unchanged) |
| 5..5+T-1 | table 0..T-1 | 4005..4005+T-1 |

## Window state

| Field | Values |
|---|---|
| ForcedEncoding | -1 detect, 0..4 |
| ForcedTable | -1, or a table index (only with ForcedEncoding = 4) |
| TableUsed | the table index the current text was decoded with, or -1 |

## Remembered table (plug-in setting)

`DefaultConvert` REG_SZ (UTF-8 in the registry, code-page bytes in memory, max 209 bytes); empty =
system code page. Transitions: choose table t (re-read succeeded) -> name(t) if it fits; choose
*System code page* (succeeded) -> empty; UTF-8 / UTF-16 choices -> unchanged.

## Which table a file gets (`SalCodeTableToUse`)

| ForcedEncoding | ForcedTable | remembered | table used when the result is single-byte |
|---|---|---|---|
| -1 | - | -1 | none (system code page) |
| -1 | - | r | r |
| 4 | -1 | any | none |
| 4 | t | any | t |
| 0..3 | - | any | none (not single-byte) |
