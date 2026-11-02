# Data model - 398

**Seed** (the pre-filled Find text)
- source: the selected bytes `[min(StartSelection, EndSelection), max(...))`, at most 402 read
- encoding: the viewer's `ContentEncoding` (0 code page, 1 UTF-8, 2 UTF-16 LE, 3 UTF-16 BE);
  code page = the ANSI code page
- result: UTF-16 text, NUL-terminated; at most 200 units; UTF-8 form at most 200 bytes; whole
  characters only; ends before the first NUL character
- no state is kept: the seed is computed at every Find dialog open (as before)
