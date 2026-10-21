# Data model - 277-ftp-pwd-path-cut

No stored data changes.

- **PWD reply**: bytes `[reply, reply + replySize)`, starting with a 3-digit code and a space or
  '-'. Path forms: RFC 959 / VxWorks `... "<path with "" for ">" ...`; German AIX
  `... '<path>' <text without ">`.
- **Result of the parse**: OK + path (at most `dirBufSize - 1` bytes, terminated), SYNTAX,
  TOOLONG. The FTP plug-in treats SYNTAX and TOOLONG alike (FALSE).
- **Server path buffer**: `FTP_MAX_PATH` = 301 bytes - unchanged.
