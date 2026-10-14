# Fix log: 178 - the description of one FS-operation source keeps a long name whole

Backlog: found by 169's review (NEXT-WORK item 19, its text): `zip.cpp` ~4041
`lstrcpyn(nameBuf, fileOrDirName, MAX_PATH)` in `CSalamanderGeneral::GetCommonFSOperSourceDescr`.

## Measured / read

The only caller that passes its own name (`panel == -1`) is the FTP client's upload of one local
file (`ftp/fs5.cpp` ~1075): the operation's caption ("file "...""). A local name of more than 259
bytes of UTF-8 (about 130 Czech letters) was cut there - possibly inside a letter - before it was
formatted. Not driven: no FTP server on this machine (a person step: upload one file with a long
accented name, look at the operation window's caption).

## Work

`src/zip.cpp`: the name is used whole (with `change` 0 `AlterFileName` only reads it); the formatted
copy is a heap buffer of its own size (`AlterFileName` keeps the length, 169); low memory: the name
as it is. The text is still shortened to the caller's buffer, at a whole letter (as before).

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Review

Independent refute-first review: nothing CRITICAL / SHOULD-FIX - every `AlterFileName` branch
writes exactly the bytes it reads (`salaltername.h`), the source is written only with `change` 1,
the panel branch unchanged, the callers accept an empty text. NITs taken: the comment, low memory
keeps the name.
