# Brief for the work packages of feature 134 (FTP client, mixed texts)

Repository `E:\Projects\tandemcommander` (Tandem Commander, WinAPI C++, derived from Open
Salamander). Branch `134-ftp-mixed-templates`. Read first, in this order:

1. `CLAUDE.md` (standing rules),
2. `specs/134-ftp-mixed-templates/spec.md` and `research.md`,
3. `specs/130-plugin-mixed-templates/agent-brief.md` - the defect, the fix pattern and **the
   reverse rule**; everything there holds here unless this brief says otherwise,
4. `specs/130-plugin-mixed-templates/triage/ftp.md`: lines 1-284 (facts for the whole plug-in:
   encodings of names, error texts and sinks, the step proposal, **"What must not be touched"**)
   and **your part** (A: 285-485, B: 486-777, C: 778-1066, D: 1067-1336). The part's table is
   your work list. It was made by reading only - check every row against the code before you
   change it; a row that is wrong is recorded, not followed.

## What is already there (do not add again)

- `const char* LoadStrU8(int resID)` - `ftp.h` / `ftp.cpp`: the resource text as UTF-8, valid
  until the plug-in unloads, any number per expression, must not be modified.
- `FTPTextToU8(text, buf, bufSize)` and `FTPGetErrorTextU8(err, buf, bufSize)` - `ftputils.h`:
  a text of unknown encoding (a server reply, a `FormatMessage` text, a value an older version
  stored) as UTF-8: valid UTF-8 is kept, anything else is read through the system code page,
  cut at a whole character. Source and target must not overlap.
- `SplLegacyToU8Alloc`, `SplU8TrimTornTail`, `SplU8ToWAlloc`, `SplDisplayTextToWAlloc`,
  `SplSetWindowTitleW` (`src/plugins/shared/splloadstru8.h`, `splunicode.h`) are included
  through `precomp.h`.
- The core's `GetCommonFSOperSourceDescr` returns its whole text as **UTF-8** now (it was a
  code-page word around a UTF-8 name). A template that wraps it is therefore `LoadStrU8`
  (`fs4.cpp:650`, `929`, `fs5.cpp:41`, `operats2.cpp:367`, `680`, `dialogs5.cpp:285-290` - the
  triage calls these "not in this feature (core)"; they ARE in this feature now).
- `char` is **unsigned** in every plug-in (`/J` in `src/plugins/shared/vcxproj/plugin_base.props`);
  the triage's notes that assume a signed `char` are wrong (measured by feature 131).

## Contracts between the packages - who gives what after this feature

Four packages edit different files of one plug-in at the same time. These contracts replace
looking into another package's files (which are changing while you work):

| Thing | Owner | After this feature |
|---|---|---|
| `FTPGetErrorText`, `FTPGetErrorTextForLog`, `FTPListingFieldToU8`, `FTPU8NameToServer`, `PrepareFTPCommand` and its log copy | nobody | **unchanged** (code page / as today). Convert at the place of use (`FTPTextToU8`, `FTPGetErrorTextU8`). |
| the log sink `CLogs::LogMessage` (`ctrlcon2.cpp`) and the helpers that end in it | A | makes **every** appended message UTF-8 on its own (valid UTF-8 kept, anything else read as code page). So: a plain resource text logged with `LoadStr` needs **no change**; a log message **composed with a name, path, reply or error text** uses `LoadStrU8` and UTF-8 pieces (a reply through `FTPTextToU8`) so that the message is not mixed inside. |
| `CSocket::GetProxyError` (`sockets.cpp`) | A | its output texts are **UTF-8**. Callers in other packages treat the text as UTF-8. |
| `GetFatalErrorTxt`, `GetWorkerErrorTxt`, `GetOperationFatalErrorTxt` | the package of the file that defines it | a `LoadStr` constant stays as it is; where the result joins a UTF-8 sentence the **caller** passes it through `FTPTextToU8`. Do not change what these return unless your own table says so and all callers are in your files. |
| `GetTypeNameForUser` / `UserDefinedSuffix` (`ftp2.cpp`, `ftp.cpp`) | B | returns **UTF-8** (the suffix loaded with `LoadStrU8`). Package C's users (`dialogs3.cpp:289`, `432`, `477`, `dialogs1.cpp:1116`, the A lists) treat it as UTF-8 and need a wide sink. |
| a text handed to another package's function whose encoding you cannot see | - | pass UTF-8 **only** to a sink this brief or the triage's sink table (section 4) says takes "valid UTF-8, else code page"; otherwise record the site. |

If your table needs a change in a file of another package, **do not make it** - write it in
your record under "Needed from package X" with file:line and the exact change.

## Rules specific to FTP

- **Never change what is sent to the server, stored, written to a listing file or compared**
  (the triage's list). The only stored things that change are named in the spec (FR-002): the
  Quick Connect address written back (`dialogs1.cpp:970`, package C) and the log's bytes.
- A server reply is bytes of unknown encoding. In a UTF-8 sentence it goes through
  `FTPTextToU8` into a local buffer (replies are short; use a buffer of the reply's own size
  times 3 where it is cheap, else the sentence buffer's size - a cut is at a whole character).
  A reply that is parsed, stored or compared is never converted in place.
- A sink that is code-page only and shows a name becomes wide in the same change as its
  callers (triage step 5 and 7). If the sink is shared with code you cannot read to the end,
  record it instead.
- `_snprintf_s(buf, _TRUNCATE, ...)` + `SplU8TrimTornTail(buf)` for every touched composition
  into a fixed buffer. A log message that must end with `\r\n` keeps it after a cut (append it
  again when the cut removed it - look how the template ends).
- Message-box captions, `TRACE` texts, the filter text modified in place
  (`ctrlcon2.cpp:1980-1987`) and `AliasBtnNames` stay as they are.
- No new resource strings, no interface change, nothing outside `src/plugins/ftp/` (the core
  and `src/plugins/shared/` are done by the session). New comments in English, short, with
  `feature 134` where the reason is not obvious. Keep each file's BOM and line endings; edit
  with exact replacements (the Edit tool), never rewrite a file. No Bash here-documents for
  writing files.
- Do **not** fix the "other defects seen" of the triage (cut paths, unbounded copies of names)
  unless the line is one you are changing anyway for this feature - list what you leave.

## Hard limits

- Edit only the files of your package inside `src/plugins/ftp/` and write one record file.
- **Do not build, do not run the program, no GUI, no registry, no git command that changes
  anything** (`git diff -- <your files>` and `git status` are fine). Three other agents edit
  other files of this directory now.
- You may compile small test programs of your own under
  `C:\Users\pavel\AppData\Local\Temp\claude\E--Projects-tandemcommander\3cc3c426-9583-446c-8ee9-724fd59e73d2\scratchpad\f134\<your letter>\`
  when a fact needs measuring. Since you cannot build the plug-in: read each changed line
  again for syntax, types (`const char*` from `LoadStrU8` where a `char*` was expected -
  `LoadStrU8` texts must not be modified or passed to a function that writes into its
  argument), and missing declarations.

## The record

Write `specs/134-ftp-mixed-templates/parts/<letter>.md`:

1. a table of **every row of your part of the triage**: file:line (today's), template id,
   verdict `FIXED` / `RIGHT AS IT IS` / `RECORDED (why)` / `TRIAGE WRONG (why)`, and for FIXED
   rows the pieces converted and the sink;
2. sites you found that the triage does not have;
3. for the FIXED rows: how a person reaches the three or four easiest ones in the user
   interface (what the probe's test server must do: which command to refuse, with what reply);
4. "Needed from package X" (see above) and anything you are not sure compiles;
5. other defects you saw and left.

Your final message: counts per verdict, the easiest rows to probe, what you need from other
packages, and what you are not sure about - precisely, with file:line. Do not claim more than
you read.
