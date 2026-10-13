# Fix log: feature 136 - FTP rows that 134 did not run

Branch `136-ftp-verify-rows` from `135-pictview-real-photos`. Session 2026-10-13 ("fix what you
can", the second critical point). Spec, plan and tasks first; no source change was needed.

## 1. What was added

The probe and server of feature 134 (`specs/134-ftp-mixed-templates/probe/`) got five rows:

- **BMK** - Connect to FTP Server (the plug-in's first menu command through a hot key): a
  bookmark `Žluťoučký kůň` is made with New; then the check box of a second New, the label of
  Rename and the question of Remove are read. No server involved.
- **PWD** - the address `ftp://jiří@127.0.0.1:2134/`: the password prompt's "Connecting to ...
  as ..." line.
- **LOGINU8 / LOGINCP** - a user whose password the server refuses with
  `530 Přihlášení odmítnuto: špatné heslo.` in UTF-8 / in code page 1250: the reply field of the
  login error dialog.
- **SAVELOG** - the Logs window: the text of the list's item (read wide), then Save log through
  the file dialog; the written file is read back.

## 2. Results

| Row | 0.1.9 Czech | 0.1.9 English | final build, both languages |
|---|---|---|---|
| BMK check box / Rename label / Remove question | **garbled** x 3 | readable | readable |
| PWD | **garbled** | **garbled** (`Connecting to "127.0.0.1" as "jiĹ™Ă­"`) | readable |
| LOGINU8 | **garbled** | **garbled** | readable |
| LOGINCP | readable | readable | readable (not worse - the reverse rule holds) |
| SAVELOG list item | readable | readable | readable |
| SAVELOG file | no mark, **not valid UTF-8**, name garbled | the same | starts with `EF BB BF`, valid UTF-8, every line readable |

Whole probe on the final build: **PASS 31, FAIL 0, NOT DRIVEN 0** in Czech and in English
(`specs/134-ftp-mixed-templates/probe/ftp134_result_*.txt`); 0.1.9 on the new rows: 6 FAIL in
Czech, 3 in English (`probe/ftp136_rows_before_v019_*.txt`). No crash, no hung dialog, the
registry key identical after every run. **No defect was found in the code of 134.**

## 3. Still not driven

Copy log (the clipboard), the lists of server types and proxy servers, the certificate text
(needs FTPS), the wait windows (a slow server), a list cell over 259 characters, the Quick
Connect address in the history, the connect error with a proxy. Steps for a person:
`specs/134-ftp-mixed-templates/quickstart.md`.
