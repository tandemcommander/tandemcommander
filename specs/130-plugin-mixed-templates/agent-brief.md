# Brief for the per-plug-in work of feature 130

Repository `E:\Projects\tandemcommander` (Tandem Commander, WinAPI C++, derived from Open
Salamander). Branch `130-plugin-mixed-templates`. Read `CLAUDE.md` (standing rules) first.

## The defect

Since plug-in interface 104 every file name and path that crosses the plug-in interface is
**UTF-8**; `SalamanderGeneral->GetErrorText()` is UTF-8 too. A plug-in's `LoadStr(id)` gives the
resource text in the **code page** of the system. A sentence composed from both
(`sprintf(buf, LoadStr(IDS_X), fileName)`) is neither valid UTF-8 nor code page. The core's
message box (and most core services) show a text that is valid UTF-8 as UTF-8 and any other
text through the code page - so in Czech, German, ... the file name (or the Windows error
text) in such a message is garbled, or, when the template has no accented letter, it works by
accident. In English everything is ASCII and nothing shows. This was GitHub issue #7; the core
was fixed in feature 127 (`specs/127-mixed-template-texts/fix-log.md` - read it, above all the
section about the review: **the reverse rule**).

## The fix pattern

- A template that meets UTF-8 text is loaded as UTF-8: `LoadStrU8(id)`. The shared helper is
  `src/plugins/shared/splloadstru8.h` (`SplLoadStrU8(gen, module, resID)`, returns
  `const char*` valid until the plug-in unloads; `SplLegacyToU8Alloc` / `SplLegacyToU8` for a
  piece of unknown encoding such as `FormatMessageA`, `strerror`, a library's text). Each
  plug-in gets, next to its own `LoadStr`:
  `const char* LoadStrU8(int resID) { return SplLoadStrU8(SalamanderGeneral, HLanguage, resID); }`
  (use the plug-in's own names for the two globals) and the declaration next to `LoadStr`'s.
  `filecomp` and `regedt` already have their own `LoadStrU8` - keep them, do not add another.
- **The reverse rule**: once a template is UTF-8, *every other piece* of that sentence and the
  *sink* must be UTF-8 too. Check each `%s` argument (another `LoadStr` text -> `LoadStrU8`; an
  `A`-API result -> convert; a number is fine) and follow the composed text to where it is
  shown or stored. Sinks that take UTF-8-or-code-page: the core's `SalMessageBox` /
  `SalMessageBoxEx` / `ShowMessageBox`, and others you verify by reading the core. Sinks that are
  code page only (`SetWindowTextA`, `SetDlgItemTextA`, `SendMessageA(WM_SETTEXT / LB_ADDSTRING ...)`,
  `MessageBoxA`, `DrawTextA`, `TextOutA`, a list view filled through `A` messages, a log file):
  there the *name* is wrong already today; the fix is a wide sink (`SetWindowTextW` with
  `SplU8ToWAlloc` / `SplDisplayTextToWAlloc`, `SplSetWindowTitleW` for a top-level window title)
  together with the UTF-8 template. When the sink is a core service you cannot verify, or a
  change would be larger than a few lines, **do not change the site - record it**.
- The caption of a message box stays `LoadStr` (it is a separate text; the core shows it
  either way) - do not touch captions.
- A touched unbounded `sprintf` into a fixed buffer becomes `_snprintf_s(buf, _TRUNCATE, ...)`
  (the buffer must be an array for that form; with a pointer pass the size) followed by
  `SplU8TrimTornTail(buf)` when the text holds a name or path (a cut inside a character makes
  the whole text invalid UTF-8 again). **A path or name itself is never cut** - if the buffer
  of a *file name or path that is used as such* is too small, record it, do not "fix" it here.
- Do **not** change a composition whose pieces are all code page and whose sink is code page -
  it is right as it is. Do not change what is unreachable. Do not touch texts written to
  files, registry, or sent over the network without proving the reader's encoding.
- Compositions are not only `printf`: also `strcat` / `lstrcat` / `strcpy` chains, `wsprintf`,
  `CString`-like `Format`, `std::string` `+`, `FormatMessage` with an insert array, helper
  functions that take a resource id and a name, error helpers that append `FormatMessageA`
  text. Find them all: read every use of `LoadStr(` in the plug-in.
- `wsprintf` cuts at 1,024 characters and `%s` with a narrow `printf` is byte-wise - fine;
  `%ls` in a narrow printf fails at the first letter above U+00FF (feature 129) - record it.
- No new resource strings, no change of the plug-in interface, no change outside the
  plug-in's own directory (and none in `src/plugins/shared/`). New comments in English, short,
  with `feature 130` where the reason is not obvious. Sources are UTF-8 with BOM, CRLF or LF as
  the file already is - **keep the BOM and the line endings** (edit with the Edit tool, exact
  replacements; never rewrite a whole file).

## Hard limits

- Edit only inside the plug-in directories given to you, and write one record file (below).
- **Do not build, do not run the program, no GUI, no registry, no git commands that change
  anything** (`git diff` / `git status` are fine). Other agents work in other plug-in
  directories of the same tree at the same time.
- Do not use Bash here-documents to write files (doubled backslashes collapse) - use the
  editor tools.

## The record

Write `specs/130-plugin-mixed-templates/triage/<plugin>.md` for each plug-in you were given:

1. how the plug-in's names are encoded where they meet the texts (evidence: file:line),
2. a table of **every** composition of a resource text with a name / path / error text / other
   non-constant text: file:line, the template id, the pieces and their encodings, the sink and
   its encoding, verdict `FIXED` / `RIGHT AS IT IS` / `RECORDED (why)`, 
3. for every `FIXED` row: how a person reaches it in the user interface (menu command, what
   must be true) - the maintainer writes a GUI probe row from it; mark the two or three that
   are easiest to reach,
4. other defects you saw on the way (do not fix them): cut names, `A` APIs on paths, `%ls`,
   buffers that can overflow.

Your final message: per plug-in the counts (fixed / right / recorded), the easiest-to-reach
fixed sites, and anything you are not sure about - precisely, with file:line. Do not claim
more than you read.
