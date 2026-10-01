# Contract: 7-Zip Technical Listing Parser (feature 084)

Covers FR-016. This is a pure function in `src/common/sal7zlist.*`, tested in
`saltests`. Input is the complete UTF-8 stdout of
`7z l -slt -ba -sccUTF-8 -scsUTF-8 -- "<archive>"`. Output is a list of records
(data-model §5), or an error.

## P1 — Grammar (as observed with 7-Zip 22.01; to be re-checked on 25.x)

**Amended after the independent review (2026-10-01, finding 2)**:

- The listing is made with **`-ba`** (bare). There is no preamble, no archive
  properties block and no `----------` separator, only item blocks.
- Without `-ba`, 7-Zip prints the archive's properties first, and a multi-line
  **archive comment** is printed there verbatim. A comment containing a line of
  ten `-` and `Path = …` lines injected a fake entry; this was demonstrated with
  a crafted ARJ.
- A `----------` line in the input therefore means the output is not the bare
  form, and it is **refused** (`SAL7Z_NOT_BARE`).
- Empty output is an empty archive.
- Item comments are flattened by 7-Zip onto one line and cannot inject.

The grammar below describes the non-bare form, kept for reference. The parser
now reads only `item-block { blank-line item-block }`.

```
preamble lines …
"--" line                     (archive properties block follows)
Key = Value lines             (archive properties: Path, Type, Physical Size, …)
blank line
"----------" line             (exactly 10 '-' : start of the item list)
item-block { blank-line item-block }
[trailing blank lines / summary]
item-block := 1*( Key " = " Value LF )
```

- Lines may end with LF or CRLF. A trailing CR is stripped.
- **Item boundaries**: a key line `Path = …` begins a new item. A blank line
  ends one.
- **Value**: everything after the first `" = "`, possibly empty.
- **Unknown keys** are ignored, and so is key order.

## P2 — Mapping

| Key | Field | Rule |
|---|---|---|
| `Path` | path | required; an item without it is an error |
| `Folder` | is directory | `+` means directory |
| `Attributes` | attributes / is directory | the token before the first space; `D` means directory |
| `Size` | size | decimal; empty means 0 |
| `Packed Size` | packed size | decimal; empty means unknown |
| `Modified` | modified | `YYYY-MM-DD hh:mm:ss` with an optional fraction (fraction ignored); absent or malformed means "no date". It is not an error |
| `Encrypted` | encrypted | `+` |

## P3 — Errors (whole listing rejected; the panel shows nothing partial)

- A `----------` line found (the output is not the bare form, P1;
  `SAL7Z_NOT_BARE`). Before the amendment this rule was the opposite: *no*
  separator was an error.
- An item without `Path`.
- A non-numeric `Size`.
- A path that is empty, absolute (`X:` or a leading `\`/`/`), or that contains
  a `..` component. This is a safety rule: the panel must never present an
  entry that would extract outside the target.

## P4 — Test fixtures (saltests)

| Fixture | Checks |
|---|---|
| Captured real output | non-ASCII names (Czech, Chinese, emoji), a directory, an empty file, a solid-block member with empty `Packed Size` |
| CRLF variant of the same output | line endings |
| Separator present (non-bare output, incl. the crafted archive comment) | rejected (P3, `SAL7Z_NOT_BARE`) |
| Item without `Path` | rejected (P3) |
| `..` component, absolute path | rejected (P3) |
| Malformed `Modified` | record accepted, no date |
