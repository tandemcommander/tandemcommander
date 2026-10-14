# Fix log: 186 - external archivers' messages: the whole command line, the path as UTF-8

Backlog: NEXT-WORK section D, "Found by the second verification of 124-128", item 4 (127).

## Read (not driven: no external archiver is installed)

- `pack1.cpp` "Command line too long": the list route cut the command line into `char[1000]`
  with `lstrcpyn` (inside a letter); the unpack and the browse routes **`strcpy`-ed it into
  `char[1000]`** while it may have `PACK_CMDLINE_MAXLEN` = 1,040 bytes - a stack overrun (found by
  the review).
- `pack2.cpp` "Path to file too long": composed from the console code-page forms of the folder and
  the name (`sourceShortName`, `namecnv`) and shown as code page - wrong letters.

## Work

- `src/pack1.cpp`: the three routes pass the command line itself (`PackErrorHandler` composes the
  message on the heap and normalizes each insert).
- `src/pack2.cpp`: the path from the UTF-8 source folder and name, on the heap, without a doubled
  backslash at a drive root.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Review

Quick refute-first review: both changes sound (`PackErrorHandlerPtr` is the core's handler or the
empty one; the inserts' length is free). Taken: the two `strcpy` overruns next to it; the doubled
backslash. Accepted: without long names the check uses the short form while the message shows the
long one.
