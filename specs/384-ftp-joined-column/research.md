# Research - 384-ftp-joined-column

## R1 - Where the joined text is decoded twice

- Decision: fix in `CFTPParserFunction::UseFunction`, case `fpfAdd_string_to_column` (`parser2.cpp`).
- Rationale: the head (`GetStringOperand` of a column) is `file->Name` / `GetStringFromColumn` -
  decoded UTF-8 since interface 104; the second operand is `pptStateVar` (raw listing bytes:
  `next_word`, `next_char`, `rest_of_line`), `pptColumnID` (decoded) or `pptString` (the rule's
  literal). Both are memcpy'd and passed to `AssignStringToColumn(.., FALSE)`, which runs
  `FTPListingFieldToU8` on the whole. Measured: `nameÄŤ.extč` (probe `result_before.txt`).
- Alternatives: re-encode the head into the code page before the join and decode once (rejected:
  a head that came as UTF-8 / WTF-8 from a mixed or UTF-8 server would be mangled; the code page
  cannot hold every UTF-8 name).

## R1a - Review 1: the head's bytes, not its decoded value (supersedes R2 for the usual case)

- Decision: the parser records, thread-locally for the line, the listing bytes each name / text
  column was assigned from; `add_string_to_column` joins them with the part's bytes and decodes the
  whole once. R2 / R4 / R5 remain the fallback for a column whose bytes are unknown (re-assigned from
  a decoded value).
- Rationale: a decoded head cannot tell its origin - `zé` may come from cp1250 `7A E9` or from bytes
  `7A C3 A9` that are cp1250 `zĂ©` and valid UTF-8; the server's code-page name set cannot tell either
  (another file registers `zé`). Joining the listed bytes reproduces what decoding the original line
  would give (review 1, MUST 1; probe row REG-COINC).

## R2 - How each kind of part is decoded

- Decision: raw part -> `FTPFieldToU8(part, len, FTPListingServer, 0)` (the listing-field rule:
  ASCII / UTF-8 / WTF-8 kept, else the code page; registers the part as a code-page text as every
  field is); literal -> `FTPFieldToU8(part, len, NULL, 0)` (the same text rule without a server:
  never a server name); column -> appended as it is.
- Rationale: item *Expected* ("the raw part decoded with the same rule as a listing field, then
  appended to the UTF-8 value"); a literal decoded alone gives what the whole-text decode gave for
  it whenever the head was ASCII, and is never the server's bytes.
- Alternatives: decode the literal with the server (rejected: it would register rule text such as
  "." as a server name - harmless for ASCII, wrong in principle).

## R3 - State evidence

- Decision: none from the joined value or its raw part (evidence flags 0).
- Rationale: feature 288 decided re-assigned columns are no evidence; the spec clarification keeps
  it (conservative - the server state is decided as before).

## R4 - Code-page name registration of the joined value

- Decision: after the join, `FTPAddServerName(srv, FTPNAME_CODEPAGE, joined)` when
  `SalFtpJoinedFieldIsCodePageName(headIsCodePageName, partReadInCodePage)` - head registered as a
  code-page name of the server (`FTPIsServerNameN`), or the raw part not valid UTF-8 / WTF-8
  (`!SalFtpListingFieldIsU8`).
- Rationale: before the fix the whole joined text went through the code-page branch, which
  registers it ("every field, as in 224"); `FTPU8NameToServer` sends a name in the code page to a
  "mixed" server only when it is a registered code-page name (`FTPHasServerName` matches a whole
  name, a path component or a leading path - not a prefix of a name, so the head alone does not
  match `nameč.extč`). Without registration a mixed server would get `DELE nameč.extč` in UTF-8.
- Limit: the per-server name table is bounded (`FTPAddServerName` stops at its bound, 288) - a
  head not registered because the bound was reached gives a joined name that is not registered
  either; then a legacy server still gets the code page by its state, a mixed one UTF-8 (288's
  limit, unchanged).

## R5 - Assigning without a second decode

- Decision: split `AssignU8StringToColumn(col, columns, char* str /* owned */, ...)` out of
  `AssignStringToColumn`; the latter decodes and calls it. The joined value is assigned with the
  former.
- Rationale: two valid WTF-8 strings joined may form a sequence `SalFtpListingFieldIsU8` refuses (a
  lead surrogate followed by a trail surrogate); a further decode would then read the whole in the
  code page again. Assigning the joined text as it is never decodes twice.

## R6 - How to reproduce without a z/VM server

- Decision: a copy of 215's `ftpmini.py` with a 7th argument LISTFMT `zvm` (CMS lines and a z/VM
  SYST reply); probe rows ZVM-CP-DEL, ZVM-CP-DL (fail before), ZVM-CP-ASCII, ZVM-UTF-DEL (controls).
- Rationale: the SYST reply `215 z/VM ...` excludes the UNIX rules (`not syst_contains("z/VM ")`),
  so autodetection reaches "IBM z/VM (CMS) 1"; the PWD reply `/` keeps the UNIX path type. With a
  UNIX SYST a UNIX rule took the listing (first attempt, fix-log).
