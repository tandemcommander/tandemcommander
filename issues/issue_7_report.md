Thank you - this report was right in every detail, including why the encoding check did not catch it. It turned out to be the visible tip of a larger class.

**Verdict: valid.** Fixed for the next release, **0.1.10** (feature 127, branch `127-mixed-template-texts`).

### What was measured on 0.1.9 (Czech)

With an automated probe on a hidden desktop:

| Case | 0.1.9 |
|---|---|
| Find Files log, a folder that cannot be listed | `Chyba při čtení adresáře: (5) PĹ™Ă­stup byl odepĹ™en.` (read from the list with `LVM_GETITEMTEXTW`) - **confirmed** |
| Find Files status line during a content search | `Vyhledávání:` right, the accented file name garbage - **confirmed** |
| Copy of a folder with a subfolder that cannot be read | the sentence right, `(5) PĹ™Ă­stup byl odepĹ™en.` - **confirmed** |

`tools/check_encoding.py` with your two additions reports exactly your 21 places plus `InformAboutIconOvrlsHanCrash`, which is correct as it is (marked as the allowed exception, as you proposed).

### What else was found

I did not stop at the list. A script now lists every composition of a `LoadStr()` template with a name, a path or `GetErrorText()` in the main program (46 of 130), and every sink was read. Besides your 21 + 4 (`codetbl.cpp`) + the status line:

- the Find window's **title** shows a non-ASCII mask as garbage (Czech, Slovak, Hungarian);
- five more message boxes / dialog texts: viewer or editor command too long, a path not found in an archive, a UNC name that cannot be created, the question about a link's content in Copy / Move, the title sentence of Copy / Move;
- the **View With / Edit With menu** items naming an external command;
- **a file name**: the name the program generates for a copy pasted into the same folder (`name - Copy.ext`) took the translated word as code-page bytes - Slovak `Kópia`, Hungarian `Másolás`;
- the Registry Editor plug-in: five questions / errors that put a key name or a Windows error text into a translated sentence;
- `LoadStrU8()` itself: when a text did not fit the rest of its rotating buffer it returned `ERROR LOADING STRING` (`LoadStr()` reloads in that case). With more callers this became reachable; it now wraps and converts again.

### What deliberately stays as it is

Some compositions are **right** because both parts are code-page text; changing only the template would break them: the font description in the configuration (the face name comes from `LOGFONTA`), the plug-in file names in the start-up progress window, the handler name in the icon-overlay crash notice. After the fix the inventory script lists only these (18 rows).

**That inventory was not the whole truth.** A second, independent verification of the finished fix found places the script cannot see (it only looks at `printf`-style calls with the `LoadStr()` inside). They are fixed as well:

- the internal viewer: *Cannot find the string '...'* and the message about a broken regular expression (also in Find Files);
- an unknown variable or environment variable in a command line (`$(...)`, `$[...]`);
- **every message of the external archivers** (`PackErrorHandler`, 89 calls: the archiver's path, the archive name, the Windows reason) - they went through `FormatMessage` in its code-page form;
- Ctrl+C in a message box: caption and text were joined as bytes, so with an accented caption the whole text was copied garbled - a case the first version of this fix made *more* visible.

Two places you flagged or that are related needed a change **together with plug-ins**, so they were not half-fixed here but in the follow-up changes: `GetCommonFSOperSourceDescr` (FTP and Undelete wrap its result in their own sentences - a UTF-8 word inside a code-page sentence would garble every item, not only accented ones) now gives UTF-8 and both plug-ins take it as such (feature 134), and the folder-creation errors that only ZIP uses are UTF-8 (feature 131). The other plug-ins were done right after, as their own change (feature 130): every use of a translated text was read in all 20 shipped plug-ins and thirteen of them were corrected - Checksum's overwrite question, the *Test Archive* results of ZIP and 7-Zip, the window titles of PictView, Database Viewer and PE Viewer, the errors of SFTP, TAR, UnISO and Renamer, and others. The title of the progress window of an archive operation, which the core set through the code page (wrong for an accented archive name even in English), is fixed with them. **The FTP client** - about 100 such places and its own rules for texts that come from the server - followed as its own change (feature 134): its messages, the operation window and the log, measured before and after against a test FTP server. All of these are part of 0.1.10 as well.

### The fix

As you proposed - the template is loaded with `LoadStrU8`, unbounded `sprintf` became `_snprintf_s(..., _TRUNCATE, ...)`, a text cut to its buffer is cut at a whole UTF-8 character, the status line's base is UTF-8 and its buffer cut uses `SalFindTrimTornTail`. Differences from your patch:

- about 45 places instead of 25 (see above);
- an independent review of the first version found three places where the fix itself would have **introduced** garbage, all "UTF-8 template meets a code-page neighbour":
  - the Copy / Move title sentence ends in the progress dialog's window title, which was set with the code-page API (and overran a 200-byte buffer with a long name) - the title is now composed and set as wide text;
  - in `codetbl.cpp` one argument was itself a `LoadStr()` text, and the paths come from `GetModuleFileNameA` - a program installed under a folder with accented letters would have shown a garbled message; both are converted;
  - the plug-in configuration message had a second code-page piece (`IDS_NUMOFSKIPPEDPLUGINNAMES`).

### Tests

Automated probe, hidden desktop, the product's registry key saved and restored:

| Run | Result |
|---|---|
| 0.1.9, Czech | **9 fail**: log, status line, Find title, the Copy error box (text and drawing), the Registry Editor question, the viewer's "not found", the broken regular expression, the archiver that cannot be started |
| fixed, Czech | **19 pass, 0 fail**; the clipboard rows not driven |
| fixed, English | 17 pass, 0 fail; the clipboard row not driven |

Rows: the Find log row exactly (`Chyba při čtení adresáře: (5) Přístup byl odepřen.`); the status line and the Find window's title during a search of a 12 GB sparse file named `Příliš žluťoučký kůň 01.bin` with the mask `*.bin;ž*.řx`; the Copy error box (window text exactly, and a capture of the drawing); the progress dialog's title during a running Copy; the Registry Editor's "key is not empty" question for a key named `Příliš žluťoučký kůň`.

**Not driven:** everything that needs the clipboard (the generated copy name, Ctrl+C in a message box - the hidden test desktop has no clipboard) and the title of a *queued* Copy. These are checked by hand before the release.

`check_encoding.py`: 22 findings before, 0 after; with one fixed line put back it reports that line. Its limits are now written down: it goes by argument names, does not see `FormatMessage` or `strcat` compositions, and does not read the plug-ins - a zero from it is necessary, not sufficient.

Unit tests 18,395 / 18,395 (the expansion of the archivers' messages is compared with `FormatMessage`; a random comparison of 279,152 templates by an independent reviewer found no difference); Debug and Release builds clean.

The fix will be part of **Tandem Commander 0.1.10**.
