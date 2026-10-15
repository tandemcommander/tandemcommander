# Fix log: 215 - FTP never acts on a cut name

Backlog (left by 141, `specs/NEXT-WORK.md`): "FTP: a file name of about 494 bytes or more makes
`PrepareFTPCommand` fail in its 501-byte buffer and the callers send an empty command" (by
reading).

## A test server

No FTP server was available here. `probe/ftpmini.py` is a minimal one (Python standard library,
127.0.0.1 only, any user, UTF-8 names, every command received logged as JSON; a path never leaves
its root). `probe/ftp215_probe.ps1` (205's SFTP driver: each row its own start of the program, the
left panel connects by the typed address `ftp://u:p@127.0.0.1:2121/row`, the command posted, every
dialog answered; an FTP error dialog answered Skip and its texts recorded) serves the row's folder
with it. The long name: 170 CJK letters + `.txt` = 514 bytes of UTF-8, 174 UTF-16 units (a valid
Windows name).

## Measured (before)

`probe/result_before.txt` (the final probe on the build without the fix - `src/plugins/ftp`
stashed): the backlog's premise was not what happens first - **the listing cut every name over
255 bytes** (`parser2.cpp`, "Salamander limitation" - the limit of the interface before 104), the
panel showed 85 of the 170 letters, and every command went to the CUT name:
- **DEL-LONG**: F8 sent `DELE <255 bytes>` (550 - the file stayed; a file of exactly that name
  would have been deleted);
- **DEL-TWIN**: two names of 90 letters + `1.txt` / `2.txt` (the same first 255 bytes) were the
  same name in the panel; F8 sent `DELE <255 bytes>`;
- **REN-LONG**: Quick Rename sent `RNFR <255 bytes>` ("Unable to rename");
- DL-LONG / UP-LONG: refused by the local side (error 206 - its paths are limited to 259 bytes);
  in an earlier run the download's local name was byte-cut to 259 bytes on its way to the disk
  thread (error 123, a split letter - with a short target folder a cut name that is valid would
  have been created: another local file);
- DL-CTL (short name): downloaded.

Read (audit, all of `src/plugins/ftp`): the worker passed 501 as the size of its 1,001-byte
command buffer, so a name of about 494+ bytes made `PrepareFTPCommand` fail and nothing was sent
(a reply timeout, the item retried); the panel's routes send by `strlen` - a CUT command without
CRLF; the quoted `SITE CHMOD` retry wrote one byte past `nameToQuotes`; the lock of an opened
server file held the name cut to 259 bytes (a long name never matched itself - the lock was off).

## Work

`src/plugins/ftp/`:
- `parser2.cpp`: a name is never cut; up to `FTP_MAX_NAME_U8` (3 * 255) bytes kept; a longer one
  (no Windows or UNIX file system has it) makes the rule not match;
- `ftp.h`: `FTP_MAX_NAME_U8`, `FTP_CMDBUF_SIZE` (1,001 bytes - every command with such a name fits);
  the worker (`operats4/6/7/8/a/b.cpp`) passes the size of its real buffer; the panel's buffers of
  View (`RETR`), Create Directory (`MKD`) and Quick Rename (`RNFR` / `RNTO`) in `ctrlcon5.cpp` are
  that size;
- `ctrlcon2.cpp` (`PrepareFTPCommand`): a command that does not fit leaves an empty buffer (never a
  cut command); the log copy is cut at a whole character;
- `operats4.cpp`: the quoted `SITE CHMOD` only when the escaped name fits; no write past the buffer;
- `fs4.cpp` / `fs5.cpp`: the Information Line's name and the transfer-mode buffers hold a whole
  name (they would overflow now: `AlterFileName` / `GetBasicName` write it whole); the download's
  target name is refused ("The path specified is too long.") when it does not fit - as the upload
  (141);
- `operats.h` / `operats9.cpp`: the opened-file lock keeps the whole name;
- `operats.h` / `operats3.cpp` / `operats5.cpp` / `datacon.h` / `datacon1.cpp`: the local disk work
  (its paths have up to 259 bytes) cut a longer path or name at a byte and worked on the result -
  another local file. Now a path that does not fit refuses the work ("file name is too long",
  `TooLong`), and so does a name for every work but creating a file or folder: there the name is
  cut at a whole character and marked (`NameCut`) - the first attempt is "too long" and the user's
  "cannot create" action applies (a prompt, skip, or the automatic rename that shortens on
  purpose); View's direct write to its cache file is refused the same way;
- (review) `ftputils.cpp` `FTPMakeVMSDirName`: never cuts (an empty name and a trace); its callers'
  buffers (`RMD` of a VMS folder, `operats4.cpp`; Quick Rename's `RNFR`, `ctrlcon5.cpp`) hold a
  whole listed name - a VMS folder name over 269 bytes was cut and sent without `.DIR;1`;
  `operats1.cpp` Solve Error dialog: names and paths cut at a whole character
  (`FTPCopyWholeChars`) - a split letter was shown through the code page and read back as other
  text, every button but Cancel refused; `fs5.cpp` View's cache name at a whole character; the
  quoted `SITE CHMOD` also within `PrepareFTPCommand`'s conversion buffer (it would switch the
  name to UTF-8); the log copy steps back at most 3 bytes (a server's code page); the AS/400
  branch of the download name measures its buffer.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 12 / 0 (the final build): DEL-LONG `DELE <514 bytes>`, deleted, keep.txt kept; DEL-TWIN
`DELE <275 bytes>`, only the other twin left; REN-LONG `RNFR <514 bytes>` / `RNTO r.txt`; DL-LONG
and UP-LONG refused (an error, no `RETR` / `STOR`, nothing created); DL-CTL downloaded.

DL-LONG's error is "(123) invalid name": the core's `SalIsValidFileNameComponent` takes a name of
more than 256 BYTES for invalid (a CJK name of 86+ letters) - recorded with 222. UP-LONG's Solve
Error dialog shows the whole letters now (it showed code-page text). A download of several items
where one target name does not fit is refused as a whole (as the upload since 141).

## Review

Refute-first review: not ready at first - MUST: the VMS folder name (above). SHOULD, all taken:
the disk work's refusal ignored the user's "cannot create" action (and its Autorename button came
back forever) - now only for the works where a cut acted on another file; the Solve Error
dialog's split letters; View's cache name; the quoted `CHMOD`'s encoding. Checked clean: every
route that submits disk work sets the flags (`InitDiskWork`; View's write in `datacon1.cpp`), the
only copy is `CopyFrom`; the refused create-and-write frees its flush buffer as any failed one;
the longest command (15 + 765 + 2 bytes) fits 1,001; a code-page form is never longer than the
UTF-8 one; `GetBasicName` / `AlterFileName` write whole names into 780-byte buffers; the upload
cache and the queue items are heap copies. NITs kept: a name over 765 bytes makes the listing
fail to parse (fails safe; practically unreachable); the Information Line's 1,000-byte cut may
split a letter (display).

Recorded in `specs/NEXT-WORK.md` from the audit of the whole plug-in (not fixed here): server
PATHS over 300 bytes are cut in several places and acted on (`ChangePath` `fs2.cpp:723/730`, the
upload target `fs5.cpp:744/856/923-1002`, `WorkingPath` `operats4.cpp:616` / `operatsb.cpp:701`,
`operats7.cpp:502`, `operatsa.cpp:121/641` / `operatsb.cpp:323`, the PWD decoding
`ftputils.cpp:1709/1735-1750`, `ReportCreateDirs` `operats9.cpp:564-598`, `AddEmptyListing`
`operats9.cpp:481`); VMS / AS/400 / OS/2 helpers that cut (`FTPAS400CutFileNamePart`,
`FTPCompleteAbsolutePath`, `FTPCutFirstDirFromRelativePath`); the opened-file lock compares with
`StrICmp` (not 092's rule); `FTPAddHexEscapeSequences` result ignored (`fs1.cpp:741`); the local
side's paths of 259 bytes (long-path support would need `CFTPDiskWork`, `CFTPFileToClose`,
`nameBackup` widened together); **`FTPU8NameToServer` sends a name the ANSI code page can hold in
that code page even to a UTF-8 server** (`ftputils.cpp:3563` - `cafe` with an accent read from a
UTF-8 listing goes out as `caf\xE9`: another name).
