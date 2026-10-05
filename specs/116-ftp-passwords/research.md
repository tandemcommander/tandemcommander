# Research: FTP passwords (feature 116)

Machine: Windows 11, ACP 1250, OEM 852. Build before: `build\tandemcommander\Debug_x64_pre116`
(a copy of `Debug_x64` at HEAD 79113272 = feature 115, without `Intermediate` folders). No GUI run
of the product today (the installed program was in use; it shares `HKCU\Software\Tandem
Commander` with every probe) - the product measurements are by code reading, the primitive below
by a scratch program; the GUI probe is written and pending (`quickstart.md`).

## 1. The code-page subclass on the password fields (item 1) [measured: primitive; code: product]

`CPasswordEditLine` (`dialogs1.cpp`) was constructed as `CWindow(hDlg, ctrlID)` ->
`AttachToControl` -> `AttachToWindow`: `GetWindowLongPtr` / `SetWindowLongPtr` (A) and
`CallWindowProc` (A). Attached to the Connect dialog's password field (`IDE_PASSWORD`) and the
proxy server dialog's (`IDE_PRXSRV_PASSWD`), only to receive Ctrl+right click (*Show password*).

`probe/m116_subclass.cpp` (scratch, run once in this session: an `ES_PASSWORD` edit in a window
that is never shown, three kinds - no subclass, the code-page subclass exactly as winliblt
installs it, the kind-keeping subclass of feature 102; WM_CHAR posted and dispatched through a W
loop and through an A loop; WM_SETTEXT W; the field read W through the subclass and A).
Result `probe/m116_subclass_result.txt`, in short:

| text | no subclass, W loop | code-page subclass (typed / set / read W) | kind-keeping subclass, W loop |
|---|---|---|---|
| `heslo-<U+0159>` (Czech, in CP 1250) | exact | typed `heslo-r` (*), set exact, read exact | exact |
| `voil<U+00E0>` (not in CP 1250) | exact | typed: the edit holds it, **read W gives `voila`**; set `voila` | exact |
| Cyrillic `Zhaba`, CJK, emoji (pair), `lone<U+D800>x` | exact | `????`, `???`, `??`, `lone?x` - typed, set and read | exact |
| fullwidth `AB` | exact | `AB` (best fit) | exact |

(*) A WM_CHAR converted to the code page uses the **keyboard layout's** code page (here the
session's English layout: CP 1252, which has no `<U+0159>` -> best fit `r`) - with a Czech layout a
Czech letter survives. Every row of the A loop loses the same characters even without a subclass;
the product's modal dialog loop is a W loop (feature 093 measured typed text in the core's
`DialogBoxParamA` dialogs: nothing lost).

Consequences in the product (code reading, `dialogs1.cpp`):
- A password typed into the Connect dialog was read (kill focus, `EditLine` -> `GetWindowTextW`
  through the subclass) as `?` / look-alikes and stored and sent so.
- **Silent corruption of a correct stored password**: `SelChanged` fills the field from the
  bookmark (`EditLine` -> `WM_SETTEXT` W through the subclass -> `????`), and the field's
  `EN_KILLFOCUS` handler reads and stores the field on **every** focus loss (it fits since 104's
  `ConnectFieldFits`). A password stored correctly as UTF-8 - typed as part of the address
  (`ftp://user:<password>@host`, which goes through the Unicode address combo) - became `????`
  when the user only tabbed through the password field. Probe row `tab UTF8`.
- The login-error dialog, the password prompt (`CEnterStrDlg`) and the Configuration's anonymous
  password have no subclass: Unicode, nothing lost there.
- Other code-page subclasses in the plug-in (`CSimpleDlgControlWindow` on the welcome message and
  the server log, `CEditRulesControlWindow` on the parsing-rules editor, list boxes): server text
  displays and an ASCII rules language, not passwords - recorded, not changed.

## 2. *Show password* (item 2) [code]

`WM_APP_SHOWPASSWORD` (Connect dialog and proxy server dialog, two copies of the same code):
`GetWindowText` (A) of the field through the code-page subclass -> code-page bytes (`?`, best
fit); `_snprintf_s` with the code-page template `IDS_PASSWORDIS`; `SalMessageBoxEx` (UTF-8 body,
code-page fallback); `CopyTextToClipboard` (code-page `CF_TEXT`). So a code-page password was
shown and copied correctly, anything else as `?` / look-alikes. A 100-byte read buffer would also
have cut a longer stored password.

## 3. The 101-byte buffers, the wire, the stored format (item 3) [code]

- **Wire**: `USER $(User)`, `PASS $(Password)`, `ACCT $(Account)` (`ftp2.cpp`
  `GetProxyScriptText`, `ExpandText`) copy the buffer's bytes verbatim - UTF-8 since feature 005
  (`EditLine` reads wide and stores UTF-8). `FTPU8NameToServer` (code page when representable) is
  applied to names in commands only, not to the login. No `OPTS UTF8` / `FEAT` negotiation exists
  in the plug-in (`grep -i "OPTS UTF8"`: none). Unchanged (094's decision).
- **The code-page form of 0.1.8**: `EditLine`'s fallback (before 104) re-read a text whose UTF-8
  did not fit 101 bytes through the code page - such passwords (51+ Czech letters) were stored
  and sent as code-page bytes; 104 replaced the fallback by a refusal and kept such stored values
  working only while untouched (`ConnectFieldFits` + `EM_GETMODIFY`), except *Retry* (T012).
- **Stored format**: `CFTPServer::EncryptedPassword` is the password manager's blob
  (`pwdmngr.cpp`): signature + `ScramblePassword` (padding, a **3-digit** decimal length, the
  bytes) [+ AES-256 + MAC]; registry `PasswordS` / `PasswordE` binary. Lengths up to 999 bytes
  round-trip - no format change is needed for 300 bytes. The anonymous password is a `REG_SZ`
  read into a `PASSWORD_MAX_SIZE` buffer (a larger buffer reads every older value).
- **Older versions and longer values**: 0.1.8 / pre-116 decrypt the whole blob, then
  `lstrcpyn(password, plain, 101)` (Connect dialog `SelChanged`, `fs2.cpp` connect) - a 200-byte
  password is cut to its first 100 bytes (possibly inside a character for 3-byte text) and sent
  so; when that version's Connect dialog password field loses the focus, the cut form may be
  stored over it (it is, when the cut text is valid UTF-8 and fits). Documented as the downgrade
  limit; probe row `compat DOWNGRADE`.
- **Login command buffers**: `ProcessProxyScript` expanded lines into `FTPCOMMAND_MAX_SIZE` (301)
  buffers (`ctrlcon1.cpp` panel login, `operats2.cpp` workers) and `ExpandText` **cuts** silently
  (CRLF included - the command would never end). With 300-byte passwords: `PASS` alone 307 bytes;
  the longest built-in line `PASS $(Password)@$(ProxyPassword)` 608 bytes. The worker then copies
  the command into `buf` declared `700 + FTP_MAX_PATH` but passed as `200 + FTP_MAX_PATH`.
- **Decision**: widen the secrets only (password, account; the proxy and anonymous passwords use
  the same constants) to `SAL_FTP_SECRET_BUF` = 301 bytes, keep the fields' 100-unit limit
  (`FTPSecretEditLine`), so the UTF-8 form of anything a field accepts fits; widen the login
  command buffers (`FTPLOGINCMD_MAX_SIZE` 1,818 bytes, static_asserts against the longest built-in
  line) and pass the worker's real buffer size. **Not widened**: user name (101), address (201),
  initial path (301) - they are parts of the plug-in's file-system paths (`ftp://user@host:port/
  path`, `FTP_USERPART_SIZE` 610, the core's path buffers, histories, bookmarks' paths); 104's
  refusal stays for them.

## 4. *Retry* and the stored bytes (item 4) [code]

`CLoginErrorDlg::Transfer` read all five fields with `EditLine`; a value that is not UTF-8 (the
0.1.8 code-page form) gets no recorded limit (104 S1), so the pre-check let it pass and
`EditLine`'s backstop refused it ("too long") - the dialog stayed. With the wider buffers it would
no longer be refused but **re-read as UTF-8** (other bytes than the account's password) - the same
change would hit the Connect dialog (its kill-focus reads the field once it fits) and the proxy
server dialog.

First approach considered: 104's `EM_GETMODIFY` ("the user did not change the field"). Rejected:
`WM_SETTEXT` clears the flag, so a password put into the field by an accessibility tool or a
password manager (UI Automation `ValuePattern.SetValue` sends `WM_SETTEXT`) would be silently
ignored and the old password used. Chosen: **the field's text is compared with the text the stored
value is shown as** (`SalFtpFieldShowsStored`: UTF-8/WTF-8 as itself, anything else through
`CP_ACP` - what `EditLine` does); equal -> keep the stored bytes; different -> read; an empty field
is always read. For a UTF-8 stored value keeping and reading give the same bytes, so the rule
changes behaviour only for the code-page form.

## 5. Found on the way - recorded, not changed

- A password typed as part of a Change Directory path (`ftp://user:password@host`, up to
  `FTP_USERPART_SIZE` 610 bytes) longer than 300 bytes is cut by `lstrcpyn` in
  `SetConnectionParameters` (before: at 100 bytes), possibly inside a character.
- A custom proxy-script line expanding to more than 1,000 bytes (workers) / 1,817 bytes (panel)
  is still cut by `ExpandText` without CRLF (pre-existing; unreachable for the built-in scripts).
- Log texts: the worker's log copy (351 bytes) and the panel login's wait-window text (301) cut a
  long user name / host inside a character (display only).
- The panel login's `proxySendCmdBuf` (holds `PASS <password>`) is not wiped when
  `StartControlConnection` returns (pre-existing; the workers' copy is wiped now).
- The code-page subclasses on server-text displays (section 1).
- User name, address and initial path keep 104's refusal for UTF-8 forms over 100 / 200 / 300
  bytes.
