# Feature Specification: FTP passwords are the text that was typed, of any script and up to 100 characters

**Feature Branch**: `116-ftp-passwords`
**Created**: 2026-10-05
**Status**: Implemented - GUI-verified 2026-10-06 (`fix-log.md` "GUI results")
**Input**: `specs/NEXT-WORK.md`, plug-in leftovers item 3 (left by features 094 and 104): the FTP
password fields keep a code-page subclass (`CPasswordEditLine`) and *Show password* reads through
the code page; since 104 a password, user name, address or initial path whose UTF-8 form exceeds
its buffer (100 bytes for a password or user name - 51+ Czech letters) is refused; the
login-error dialog's *Retry* refuses an untouched long password that 0.1.8 saved in code-page
form (104 T012). Widening the FTP buffers is open.

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options. No GUI run
was possible today (the installed program was in use - it shares the registry key with every
probe): the measurements are a scratch program (the subclass primitive) and code reading
(`research.md`); the GUI evidence is the pending probe (`quickstart.md`).

- Q: Does the code-page subclass lose typed characters? -> A: **Yes, and more than typed ones.**
  Measured (`probe/m116_subclass_result.txt`): with the subclass every character outside the
  system code page that is typed, shown or read becomes `?` (Cyrillic, CJK, emoji, a lone
  surrogate) or a best-fit look-alike (`voil<U+00E0>` -> `voila`, fullwidth `AB` -> `AB`); a typed
  Czech letter depends on the keyboard layout's code page. And because the Connect dialog re-reads
  its password field whenever the field loses the focus, a password that was stored correctly
  (typed as `ftp://user:password@host` into the address field) was shown as `????` and **stored
  back as `????` when the user only tabbed through the field**. Fix: the subclass keeps the edit
  a Unicode window (`AttachToWindowKeepKind`, feature 102).
- Q: *Show password*? -> A: Read as UTF-16, the message composed in UTF-16 (template from the
  language module + the password) and handed to the box as UTF-8, copied with
  `CopyTextToClipboardW`; every copy wiped.
- Q: Widen the buffers? -> A: **The secrets, yes; user name, address and initial path, no.** The
  password, the account (ACCT), the proxy password and the anonymous password get 301-byte
  buffers - the UTF-8 form of the longest text their field accepts (100 UTF-16 units x 3 bytes) -
  and keep their 100-character limit, so a secret can never be "too long" or cut. The stored
  format does not change (the password manager's scrambled / AES blob holds up to 999 bytes; the
  registry value is binary). User name, address and initial path become parts of the plug-in's
  paths (`ftp://user@host:port/path`, `FTP_USERPART_SIZE`, the core's path limits, histories) -
  widening them is a different, larger change; they keep 104's refusal (recorded).
- Q: Which bytes go to the server? -> A: Unchanged: `USER`, `PASS` and `ACCT` carry the UTF-8
  bytes of the text (since feature 005; no `OPTS UTF8` negotiation, no server-encoding setting -
  094's decision). The login command buffers grow with the secrets (`FTPLOGINCMD_MAX_SIZE`; the
  operations' workers pass their real 1,001-byte buffer) - a 300-byte password would otherwise
  have been cut, CRLF included.
- Q: Old values, older versions? -> A: Every stored value loads. A password of up to 100 bytes is
  stored exactly as before and read by every older version. A password over 100 bytes saved by
  this version is cut to its first 100 bytes by 0.1.8 and the pre-116 builds (their buffers) -
  documented downgrade limit (CHANGELOG), probe row `compat DOWNGRADE`.
- Q: *Retry* in the login-error dialog with a password 0.1.8 saved in code-page form? -> A: A
  field that still shows the stored value keeps the stored **bytes**; a field with any other text
  is read. The rule compares texts (`SalFtpFieldShowsStored`), not the edit's "modified" flag: a
  program that fills a field with `WM_SETTEXT` (an accessibility or password tool) clears that
  flag, and its text must not be ignored. Applied to the login-error dialog (all five fields), the
  Connect dialog's password field and the proxy server dialog's password field. An empty field is
  always read (the dialogs empty a field to delete a value).
- Q: PRIVACY.md? -> A: Unchanged: what is stored, where and how it is protected do not change
  (the same password manager form; a password is now stored as typed, up to 300 bytes). Recorded
  in `fix-log.md`.
- Q: Interface, strings, configuration? -> A: Plug-in interface 107, no new string, no registry
  format change, no configuration version change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A password in any script reaches the server as typed (Priority: P1)

A user types a password with Cyrillic, CJK, emoji or accented letters into the FTP Connect
dialog; the server receives exactly its UTF-8 bytes, and the saved bookmark keeps them.

**Acceptance Scenarios**:

1. **Given** the Connect dialog, **When** the user types `Zhaba` (Cyrillic) and connects, **Then**
   the server receives `d0 96 d0 b0 d0 b1 d0 b0` (before: `3f 3f 3f 3f`).
2. **Given** a bookmark whose password `Zhaba` was saved correctly, **When** the user only tabs
   through the password field and closes the dialog, **Then** the stored password is unchanged
   (before: it became `????`).
3. **Given** a typed `voil<U+00E0>` or fullwidth `AB`, **Then** the server receives exactly those
   characters (before: the look-alikes `voila`, `AB`).

### User Story 2 - Show password shows the password (Priority: P2)

1. **Given** a password field holding `Zhaba` + CJK + an emoji, **When** the user Ctrl+right-clicks
   and confirms, **Then** the box shows exactly that text and *Yes* copies it as Unicode text
   (before: `?` for every such character).

### User Story 3 - A long password is taken (Priority: P2)

1. **Given** 100 Czech letters (200 bytes) or 100 CJK characters (300 bytes) typed as a password,
   **When** the user connects, **Then** the server receives them whole and the bookmark stores
   them (since 104: "too long"; 0.1.8: code-page bytes).
2. **Given** the "enter password" prompt, **When** 100 Czech letters are typed, **Then** they are
   sent whole.
3. **Given** a 101st character, **Then** the field does not take it (unchanged limit).

### User Story 4 - A password saved by 0.1.8 keeps working, Retry included (Priority: P2)

1. **Given** a bookmark with a password 0.1.8 saved in code-page form (60 Czech letters as 60
   bytes), **When** the user connects and the server refuses, **Then** *Retry* with the field
   untouched sends the same 60 bytes again (since 104: "too long", the dialog stayed).
2. **Given** the same bookmark, **When** the user tabs through the field and closes the dialog,
   **Then** the stored blob is byte-identical.
3. **Given** the login-error dialog, **When** the user types a new long password and retries,
   **Then** its UTF-8 bytes are sent.

### Edge Cases

- A text set into a secret field by another program past its 100-character limit (only
  `WM_SETTEXT` can) and longer than 300 bytes: refused with Windows' "too long" text, nothing
  stored (104's rule, unchanged).
- A user name of 51+ Czech letters: refused as in 104 (not widened).
- A password over 100 bytes opened by an older version: cut to 100 bytes there (documented).
- A Master Password: the stored blob is AES-encrypted; the rule decrypts it to compare (the field
  is shown only when it can be decrypted).
- A SOCKS 5 proxy carries at most 255 bytes of user name and of password (RFC 1929): the proxy
  server dialog refuses more ("too long"), and a longer value from a prompt fails the connection
  instead of being cut (review T015).
- A refused field in the login-error dialog or the proxy server dialog: nothing is stored, the
  previous values stay (review T015).

## Requirements *(mandatory)*

- **FR-001**: The FTP password fields MUST be Unicode windows: typed, shown and read text MUST
  not pass through the code page.
- **FR-002**: *Show password* MUST show and copy the field's text exactly.
- **FR-003**: Every secret field (password, account, proxy password, anonymous password, the
  password prompts) MUST hold the UTF-8 form of any text its field accepts; the field limit stays
  100 UTF-16 units.
- **FR-004**: The login commands MUST be built in buffers that hold the longest built-in script
  line with the widened secrets.
- **FR-005**: A dialog MUST keep a stored value's bytes when its field still shows that value, and
  read the field otherwise; an empty field MUST be read.
- **FR-006**: A refused text MUST never be stored, sent or replace a stored value (104 B1).
- **FR-007**: The stored format MUST stay readable by older versions for passwords of up to 100
  bytes; the downgrade limit for longer ones MUST be documented.
- **FR-008**: Password copies made by the changed code MUST be wiped.
- **FR-009**: No plug-in interface, string, registry format or configuration version change.

## Success Criteria *(mandatory)*

- **SC-001**: Probe `probe/ftppwd_probe.ps1` on this build: every row PASS (except NOT DRIVEN
  routes); on the build before (`-Expect before`): every defect row shows the defect.
- **SC-002**: saltests 14,401 -> 14,441 / 0; strict encoding guard TOTAL 0; Debug and full Release
  builds succeed with no warning in a changed file.
- **SC-003**: No other feature's probe is affected (no shared code changed); 104's `ftp-b1` rows
  are superseded by this probe (LONGPWD / CONNECT now accepted by design; LONGUSER, the refusal
  backstop and LEGACY repeated here).
