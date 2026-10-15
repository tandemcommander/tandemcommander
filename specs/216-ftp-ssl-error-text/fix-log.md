# Fix log: 216 - the FTP plug-in's SSL texts keep OpenSSL's contract and reach the log readable

Backlog (left by 137, `specs/NEXT-WORK.md`): `ssl.cpp:666` `name[200]` for a call that may write
256 bytes.

## Read (not driven)

`CSocket::EncryptSocket` (`src/plugins/ftp/ssl.cpp`):
- `ERR_error_string(err, name)` with `char name[200]` - the shipped OpenSSL 1.0.1c writes up to 256
  bytes (`ERR_error_string_n(e, buf, 256)`): the contract broken. (The code passed there is a
  `SSL_get_error` result, 0-8, so the text is about 40 characters - not reached in practice.)
- the log lines were made by `sprintf` / `wsprintf` into `char buffer[256]` with no bound; the
  certificate's subject and issuer are cut to 199 characters by `X509_NAME_oneline` (ASCII,
  escaped), the longest translated template (Ukrainian, code page) had about 52 bytes: at most 252
  of 256 - a near miss, not an overflow a server could cause;
- the log lines and the error text took `LoadStr` (the code page of the system): a UI language
  outside it (Czech on a cp1252 system) lost its letters in the FTP log.

Not driven: it needs an FTPS server; the test server of 215 has no TLS. A step owed to a person:
connect to an FTPS server (Czech or Ukrainian UI), read the SSL lines of the log.

## Work

`ssl.cpp`: `name[256]`, `buffer[1024]` (with `LoadStrU8` the Ukrainian template has about 91
bytes - the old 256 would not hold a line); every line by `_snprintf_s(..., _TRUNCATE)`; the log's
and the error's texts by `LoadStrU8`; (review) `ctrlcon1.cpp` the two certificate log lines
(accepted / rejected) by `LoadStrU8`; the comment of `WriteSSLErrorStackToLog`'s buffer.

Build: BUILD SUCCEEDED. Regression: 215's FTP probe 12 / 0 (`probe/regress_215.txt`).

## Review

Refute-first review: accept. The format arguments match (`%d` int, `%s` `const char*`); the sinks
take either encoding (`CLogs::LogMessage` makes each message UTF-8 and repairs a torn tail;
`CFTPU8Piece` / `FTPTextToU8` / `WorkerErrDescrToU8` for the error texts). Taken: the claims of
this log (above - no server-reachable overflow), the two lines of `ctrlcon1.cpp`, the comment.
NITs kept: the logged `ERR_error_string(err)` is given an `SSL_get_error` code (says little; the
error stack is logged anyway); `ssl.cpp:259` converts the host name through `CP_ACP` (an ASCII host
name in practice).
