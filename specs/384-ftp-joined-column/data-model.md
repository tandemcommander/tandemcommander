# Data model - 384-ftp-joined-column

No stored data. In-memory values of one parse:

| Value | Form | Source |
|---|---|---|
| Head | UTF-8 / WTF-8, NUL-terminated | the column's current value (`file->Name` or `GetStringFromColumn`) |
| Appended part | raw bytes (`pptStateVar`), UTF-8 (`pptColumnID`), rule text (`pptString`) | the second operand of `add_string_to_column` |
| Part kind | `SALFTPJOIN_RAW` / `SALFTPJOIN_COLUMN` / `SALFTPJOIN_LITERAL` | the operand type |
| Joined value | UTF-8 = head + decoded part, owned by the column after assignment | `FTPListingJoinFieldU8` |
| Server's code-page names | per-server bounded set (288) | `FTPAddServerName(srv, FTPNAME_CODEPAGE, ..)` |

Rules (pure, `salftpsrvenc.h`):

- `SalFtpJoinPartHandling(kind)`: RAW -> decode as a listing field of the server; LITERAL -> decode
  alone (no server); COLUMN (and any other value) -> append as it is.
- `SalFtpJoinedFieldIsCodePageName(headIsCodePageName, partReadInCodePage)`: TRUE when either holds.

Validation: an empty part appends nothing (the column keeps its value, as before); a joined name
over `FTP_MAX_NAME_U8` bytes fails the rule (215); low memory sets `lowMemErr`.
