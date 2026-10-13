# Research: feature 130

## R1. How a plug-in gets a UTF-8 template

- **Decision**: one shared header (`splloadstru8.h`) with a per-module cache; each plug-in adds
  `const char* LoadStrU8(int resID)` next to its `LoadStr`. File Comparator (102) and the
  Registry Editor (124) keep their own.
- **Rationale**: `LoadStrW` of the core returns a rotating buffer; a kept UTF-8 copy has no
  lifetime trap (several texts in one expression, any thread). A critical section, not a slim
  lock: some plug-ins compile with a Windows version macro before Vista (the first build failed
  on exactly that).
- **Alternatives**: a rotating thread-local buffer (memory per thread in 20 DLLs, lifetime traps);
  a new core service (an interface change - not needed).

## R2. What the sinks do (read in the core, checked by two reviewers)

| Sink | Shows valid UTF-8 as UTF-8 | Where |
|---|---|---|
| `SalMessageBox` / `SalMessageBoxEx` / `ShowMessageBox` | yes | `msgbox.cpp` |
| `DialogError` text | yes | `dialogs.cpp` |
| progress dialog lines (`ProgressDialogAddText`) | yes | `gui.cpp` (`CStaticText::SetText`) |
| progress dialog **title** (`OpenProgressDialog`) | **no - `SetWindowText` A** -> fixed in the core here | `zip.cpp` |
| viewer caption given by a viewer plug-in | yes | `viewer3.cpp` |
| a plug-in's own `SetWindowTextA` / `SetDlgItemTextA` control | no | needs a wide call |

## R3. The reverse rule

Once the template is UTF-8, every other piece must be: another resource text (`LoadStrU8`), a
`FormatMessage` A text (wide call or `SplLegacyToU8`), a remote name whose bytes are the
server's (SFTP: `CSFTPMsgText` - valid UTF-8 kept, else read as code page), a pseudo name kept in
code page because it is compared with `LoadStr` elsewhere (PictView). The review found one
missed piece (SFTP download: the local path ends with the remote name).

## R4. What is not changed

- Sentences whose pieces are all code page in a code-page-tolerant sink - right as they are
  (listed per plug-in in `triage/`).
- Texts written to files (ZIP self-extractor settings, UnISO viewer text), names used as file
  names (Undelete's virtual folders), texts sent to a server.
- FTP: about 104 sites; the log is one byte string of mixed encodings, server replies are
  pieces of about 25 sentences, the core hands it a mixed text (`GetCommonFSOperSourceDescr`);
  needs a test server and a decision about the log's bytes -> its own feature.

## R5. The progress dialog's title

- **Decision**: fix the core (`CZIPUnpackProgress`, `WM_INITDIALOG`): `SalLegacyToU8Alloc` ->
  wide -> `SalSetWindowTitleW`. One place instead of a workaround in each plug-in (the ZIP
  agent's first version set the title twice from the plug-in).
- **Compatibility**: a title that is not valid UTF-8 (an older plug-in) is read as code page,
  as before.
