# Fix log: 185 - cut message texts end at a whole letter; the clipboard copy of a plug-in's URL

Backlog: NEXT-WORK section D, "Found by the second verification of 124-128", items 8 and 9.

## Read (not driven)

- Item 8: nine message compositions with `_snprintf_s(..., _TRUNCATE, ...)` without a tail trim
  (`find.cpp` x5 - the Find log; `dialogs3.cpp` - the drive label; `icncache.cpp` x2 - the
  associations; `mainwnd4.cpp` - a temporary file): a text cut there ends inside a letter (a broken
  glyph). The buffers fit the shipped languages' templates (a cut needs a long template - Russian /
  Ukrainian, disabled - or a long error text). `salamdr2.cpp` (user menu variables): a typed
  variable name cut at MAX_PATH - 1 bytes for the message; an environment variable name of
  MAX_PATH bytes or more was looked up CUT - another variable.
- Item 9: `msgbox.cpp` copy to the clipboard: a plug-in's URL / URL text were not normalized to
  UTF-8 and went through `wsprintf` (at most 1,024 characters - cut, possibly inside a letter). The
  hidden desktop has no clipboard - a person step (Ctrl+C in a plug-in message box with a link).

## Work

- `SalU8TrimIncompleteTail` after the nine compositions; the variable name trimmed the same way.
- `salamdr2.cpp`: an environment variable name of MAX_PATH bytes or more is not looked up (it is
  "not found"); the message shows it cut at a whole letter.
- `msgbox.cpp`: the URL and its text through `SalLegacyToU8Alloc`, copied whole with `strcpy`
  into the buffer sized for them.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Review

Quick refute-first reviews: `SalU8TrimIncompleteTail` changes nothing on an uncut or empty text,
the calls sit after the right statements (two multi-line), the empty environment name fails into the
existing "not found"; the message's name taken (review NIT). The clipboard part: the size covers
what is written, every exit frees both copies, NULL / low memory leave the URL out. Recorded: the
dialog itself shows a plug-in's code-page URL text as UTF-8 (garbled on screen, right on the
clipboard).
