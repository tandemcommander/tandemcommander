# Research - 262 Code Viewer code tables

## R1 How the built-in viewer shows a converted file

- Decision: bytes through the 256-byte table (`*s = table[(unsigned char)*s]`), then read in the
  system code page (`MultiByteToWideChar(CP_ACP)`).
- Rationale: the built-in viewer applies `CodeTable` to the bytes (viewer2.cpp `UseCodeTable`) and
  draws them with `TextOut` (A) and the ANSI viewer font (`lfCharSet = UserCharset`) - i.e. in the
  system code page. Same letters in both viewers.
- Alternatives: decoding with the code page named by the table's target (`- CP1250`) - rejected:
  names are free text, and targets like `ASCII` / `Cork` have no Windows code page; the built-in
  viewer does not do it either.

## R2 Where the list comes from

- Decision: `SalamanderGeneral->EnumConversionTables(parent, &index, &name, &table)`, once per
  window when its menu is built; `name == NULL` = separator; `name` / `table` stay valid for the
  program's life (spl_gen.h), so the window keeps the pointers.
- Rationale: it is exactly the built-in viewer's list (`CCodeTables::EnumCodeTables` over the
  active `convert\<dir>\convert.cfg`); dbviewer and filecomp use the same service. Callable from
  any thread (viewer windows run on their own threads).
- Alternatives: `GetConversionTable(name)` per choice - not needed once the pointers are kept;
  a new UTF-8 service - a plug-in interface change (maintainer-owned, B-5).

## R3 Names are code-page bytes (B-5 invariant)

- Decision: the window keeps the names as handed out; the menu uses `AppendMenuA` (the existing
  menu is built with A calls, the dark menu reads it with `GetMenuItemInfoA`); the status bar
  converts the display name with `MultiByteToWideChar(CP_ACP)`; the remembered name is matched byte
  for byte against the handed-out names.
- Persisting: the registry facade (`SalRegSetValueExW8`) takes UTF-8, so `config.cpp` converts the
  code-page name -> wide -> UTF-8 on save and UTF-8 -> wide -> code page (no best fit, default-char
  check) on load; a value that does not convert back exactly is dropped (= system code page), never
  guessed. All shipped names are ASCII, so the conversion is the identity for them.
- Alternatives: storing the raw bytes as dbviewer does - would be read as UTF-8 by the facade and a
  non-ASCII name would not survive (dbviewer's latent defect; ASCII names hide it).

## R4 What "remembered" means here

- Decision: one remembered name (`DefaultConvert`), set when the user chooses a table, cleared when
  the user chooses *System code page*, applied to files detected as single-byte; read when a file is
  opened (`OpenFile`, next / previous file); other open windows are not re-decoded.
- Rationale: the built-in viewer's remembered default (`Configuration.DefaultConvert`) is likewise one
  table name applied to every single-byte file; an explicit *Set as default* command and *Auto-Select*
  would need new UI strings (the `.slt` refresh, which a run cannot do) - leftover item.
- A name longer than the stored buffer (210 bytes, as dbviewer) is not remembered (refuse, never
  cut); the open file is still decoded with it.

## R5 Threads

- Decision: the remembered name lives in codeview.cpp behind a critical section (the existing
  `CvPendingCS` pattern: created in `DllMain` attach); `CvGetDefaultConvert(char*, int)` /
  `CvSetDefaultConvert(const char*)`. Load / Save run on the main thread, choices on viewer threads.

## R6 How to prove it

- `saltests`: the real `convert/centeuro/c8521250.tab` and `iso21250.tab` bytes embedded (256 bytes
  each, generated from the files) applied to the corpus lines, decoded with code page 1250 ->
  exactly "Příliš žluťoučký kůň úpěl ďábelské ódy"; identity for ASCII; display name; cycle wrap;
  menu-id mapping; the table choice for detect / forced / remembered.
- GUI: the decoded text lives in a WebView2 page; no existing probe reads it. The window's status bar
  (a Win32 status control) can be read with `SB_GETTEXTW`... from another process only through
  shared memory - not attempted. A person checks the menu, the letters and the remembering
  (person-step at closing). The intake itself is covered by the unit rule plus a build.
