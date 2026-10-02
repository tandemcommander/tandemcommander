# Feature Specification: Passwords in the ZIP and SFTP plug-ins are the text that was typed

**Feature Branch**: `094-plugin-password-encoding`
**Created**: 2026-10-02
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5 (left by feature 093): *"The ZIP and SFTP password prompts were not examined for the defect the 7zip plugin had - check them next."* The maintainer asked for a measurement first and a fix only according to its result.

## Clarifications

### Session 2026-10-02

The maintainer is away and asked for full autonomy; every decision below is the author's recommended option. The measurement is `research.md` (code reading plus experiments through the product on a hidden desktop, with 7-Zip 22.01 and a logging SSH server as references).

- Q: Do the ZIP and SFTP plug-ins garble passwords the way the 7zip plug-in did? → A: **No.** Neither reads UTF-8 as code-page text. A password made of characters of the system code page (for example `heslo-ř` on a Czech Windows) works in both, and 7-Zip opens what the ZIP plug-in creates.
- Q: What is wrong then? → A: **ZIP: characters outside the system code page.** The plug-in reads the password field through the code page, so each such character becomes `?` before it is used. An archive "protected" with a six-letter Cyrillic word on a Czech Windows is really protected with `??????`: any other six-letter Cyrillic word opens it, the typed word does not open it in other programs, and nothing tells the user. Also: archives whose key was made from UTF-8 bytes (other platforms) never open; AES archives keyed with OEM bytes do not open; a 255-character password is silently cut to 254; the password is written into the text a crash report prints. **SFTP: one edge** - a password or passphrase of 512 or more UTF-8 bytes is re-read through the code page and sent garbled.
- Q: Which bytes should a new ZIP archive be encrypted with? → A: **Unchanged for text the system code page can represent: the code-page bytes.** That is what every earlier version wrote and reads, and what 7-Zip opens; changing it would make new archives unreadable for 7-Zip and for installed earlier versions. **For text the code page cannot represent: the UTF-8 bytes** - never the `?` form again. Chosen over refusing such passwords (what 7-Zip does for every non-ASCII password): no installed tool can open such an archive with the typed text under the code-page rule anyway, UTF-8 is what tools on other platforms use, and with it the archive opens in this program on any computer, whatever its code page.
- Q: How do existing archives keep opening? → A: **The typed text is tried in several byte forms, in a fixed order**: code page, OEM, UTF-8, and - only for text the code page cannot represent - the old `?` form, so that archives earlier versions made with such passwords still open with the password the user remembers. For the classic ZIP encryption, whose password check lets a wrong form through 1 time in 256, the remaining forms are tried when the unpacked data fails its checksum.
- Q: SFTP? → A: **Remove the edge**: the three secret fields are read into storage large enough for the longest text the field accepts, so the code-page re-read cannot happen. No new message, no change for any password that works today.
- Q: FTP? → A: **Not changed.** Its password goes to the server as the UTF-8 bytes typed - not the 7zip defect; which encoding an FTP server expects is not knowable and there is no setting for it. Its 101-byte buffer has the same long-password edge as SFTP (51 or more two-byte characters); recorded for the backlog with the shared dialog library's fallback.
- Q: User-visible text? → A: **No new or changed strings** (no translation work): nothing is refused that was accepted before.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A ZIP password with characters outside the code page protects the archive (Priority: P1)

On a Czech Windows a user packs files into an encrypted ZIP archive with the password `пароль`. Today the archive is protected with `??????`. After the change it is protected with the typed word; a different word does not open it; the same word opens it in this program on any computer.

**Why this priority**: the user believes the archive is protected by their password and it is not - a silent weakening.

**Independent Test**: pack through the product with such a password; a script that derives the key from candidate byte strings shows which bytes the archive is keyed with; another six-letter Cyrillic word is refused.

**Acceptance Scenarios**:

1. **Given** a password the system code page cannot represent, **When** an archive is created or files are added (classic encryption and AES), **Then** it is keyed with the UTF-8 bytes of the typed text, and a different text of the same length does not open it.
2. **Given** a password the code page can represent (ASCII, `heslo-ř`), **Then** the archive is keyed exactly as before (code-page bytes) and 7-Zip opens it with the typed password.
3. **Given** a 255-character password, **Then** all 255 characters are used.

### User Story 2 - Existing and foreign ZIP archives open with the password the user knows (Priority: P1)

Archives made by earlier versions with a Cyrillic password (keyed with `?`), archives from other platforms keyed with UTF-8 bytes, and AES archives keyed with OEM bytes open when the right password is typed.

**Independent Test**: fixtures keyed with each byte form (made by a script); unpack through the product with the typed text; compare content.

**Acceptance Scenarios**:

1. **Given** an archive an earlier version made with an out-of-code-page password, **When** that password is typed, **Then** it unpacks.
2. **Given** an archive keyed with UTF-8 bytes, or an AES archive keyed with OEM bytes, **Then** it unpacks.
3. **Given** a wrong password, **Then** the behaviour is as before: the "incorrect password" prompt, nothing unpacked as if correct.
4. **Given** the classic encryption and a byte form that passes the 1-in-256 check by chance but is wrong, **Then** the right form is still found and the file unpacks correctly.
5. **Given** an ASCII password, **Then** nothing changes - one form, one attempt.

### User Story 3 - A very long SFTP password or passphrase is sent as typed (Priority: P3)

A password or key passphrase of 512 or more UTF-8 bytes (for example 256 accented letters) reaches the server as the typed text.

**Independent Test**: the logging SSH server of the research records the bytes received for a 256-letter accented password: exact UTF-8.

**Acceptance Scenarios**:

1. **Given** a secret at the field's maximum length made of two-, three- or four-byte characters, **Then** the bytes handed to the SSH library are its UTF-8 form.
2. **Given** any secret that works today, **Then** the bytes are unchanged.

### Edge Cases

- A text whose code-page and OEM forms are equal, or whose UTF-8 form equals the code-page form (ASCII): each distinct byte string is tried once.
- AES limits the password to 128 bytes: the limit applies to the byte form actually used; a typed text whose chosen form is longer is refused with the existing message.
- The remembered passwords of one unpacking session (several archives items with different passwords) keep working; a form is remembered only after it verified.
- A password that cannot be represented and whose `?` form equals another candidate.
- The self-extracting archive stub has its own password prompt in a separate program: not changed, recorded.
- A crash while a password is in use: the report must not print the password.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ZIP plug-in MUST read typed passwords as Unicode text (no code-page read of the field) and MUST use all characters the field accepts.
- **FR-002**: For creating and updating archives the ZIP plug-in MUST key with the code-page bytes when the text is representable in the system code page, and with the UTF-8 bytes otherwise. It MUST NOT substitute characters.
- **FR-003**: For unpacking, testing and viewing, the ZIP plug-in MUST try the typed text as: code-page bytes (when representable), OEM bytes (when representable), UTF-8 bytes, and the substituted (`?`) code-page form when the text is not representable - each distinct byte string once, in that order, for both encryption methods.
- **FR-004**: For the classic encryption a form that passes the password check but yields data failing the checksum MUST NOT end the attempt: the remaining forms are tried before an error is reported. A form is remembered for the session only after it verified.
- **FR-005**: A wrong password MUST behave as before (same prompt, same messages); an ASCII password MUST take exactly the old path.
- **FR-006**: The ZIP plug-in MUST NOT write a password into the call-stack text, and MUST wipe password buffers it no longer needs.
- **FR-007**: The SFTP plug-in's secret fields MUST be read into storage sufficient for the longest accepted text, so that no secret is re-read through the code page.
- **FR-008**: No user-visible string is added or changed; the plug-in interface version does not change; archives and stored bookmarks written by earlier versions keep working.
- **FR-009**: The FTP plug-in, the self-extractor stub and the shared dialog library's fallback are not changed; each is recorded with its reason.

### Key Entities

- **Password form**: one byte string derived from the typed text (code page, OEM, UTF-8, substituted).
- **Representable text**: text every character of which exists in the system code page.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An archive packed through the product with an out-of-code-page password is keyed with its UTF-8 bytes; **0** of the tested different passwords of the same length open it (before: every one did).
- **SC-002**: Archives packed with ASCII and with in-code-page passwords are byte-form-identical to those of the previous build and 7-Zip opens them.
- **SC-003**: **100 %** of the fixture archives keyed with code-page, OEM, UTF-8 and substituted forms, for both encryption methods, unpack with the typed text; the previous build fails on the UTF-8 fixtures and on the OEM AES fixture.
- **SC-004**: Wrong-password rows give the same result as the previous build.
- **SC-005**: A 512-byte-or-longer SFTP secret arrives at the logging server as exact UTF-8.
- **SC-006**: Debug and Release builds succeed; unit tests, the strict encoding guard and the earlier probes pass.

## Assumptions

- The reference for "what other tools open" is 7-Zip 22.01 on this machine (it uses code-page bytes for both methods and refuses to create with a non-ASCII password); WinZip and Windows Explorer are not installed.
- GUI probes run on the hidden desktop; a real-keyboard pass stays owed to a person.
