# Fix log: 205 - FTP and SFTP downloads never write into another entry by its short name

Found by the review of 203: a download's local name may be only the short (8.3) name of another
local entry ("LONGFI~1.TXT" next to "longfilename.txt", "LONGDI~1" next to the folder
"longdirname") - Windows opens that other entry under it. 203 made the core's create paths move
such a clash aside; the FTP plug-in turns their error back into "it exists", the SFTP plug-in never
uses them.

## Measured (before)

Probe `probe/sftp205_probe.ps1` (the driver of 133's `sftp133_probe.ps1`; the Docker test server
`tandem-sftp`, fixture `probe/fixture205.sh`; short names are made on C:), F5 out of the server
panel, every box answered Yes. The build at 204 (`probe/result_before.txt`, 4 / 4):
- **SF-FILE** (download `LONGFI~1.TXT` next to `longfilename.txt`, nothing held): "The local file
  already exists: ...\LONGFI~1.TXT Overwrite it?" - Yes **replaced the content of
  `longfilename.txt`** with the download;
- **SF-HELD** (`longfilename.txt` held open): the same question (the replace failed on the handle);
- **SF-DIR** (the folder `LONGDI~1` with `a.txt`): no question - **downloaded into `longdirname`**;
- **SF-DIRSAME** (`LONGDI~1` holding `keep.txt`): the question for `LONGDI~1\keep.txt` - Yes
  **replaced `longdirname\keep.txt`**.

FTP: no FTP server here - not driven. By the code (203's review): `DoCreateDir` / `DoCreateFile`
(`operats5.cpp`) re-check a failed create with `SalGetFileAttributes`, which finds the other entry
through the short name - "exists": a folder joined into the other folder (the default "join"),
the other file offered for overwriting or resuming.

## Work

- `src/plugins/shared/splshortname.h` (new, header-only for plug-ins):
  `SplPathIsOnlyShortNameOfOther` - TRUE only when proven: the name equals the short name of the
  entry found under it and not its long name (`SalNameOrderEqualCI`, the 092 rule); not found, a
  folder that cannot be listed, a root, "." / ".." - FALSE (the old handling).
- `src/plugins/ftp/operats5.cpp`: the re-check turns a failed create into "exists" - and
  `alreadyExists` is set - only for an entry not proven such an alias; otherwise the "cannot
  create" handling with the create's own error (prompt / autorename / skip, as configured).
- `src/plugins/sftp/operats.cpp`: a file whose local name is proven an alias is created by the core
  (`SalCreateFileEx`: the other entry moved aside and back; failing that "Cannot open local file"
  and a log line with the error) - the existence, overwrite and resume block is not entered; a
  folder is made by `SalCreateDirectoryEx` instead of `CreateDirectoryW`, and one still proven an
  alias after a failed create is refused.

Build: BUILD SUCCEEDED (ftp.spl, sftp.spl).

## Measured (after)

`probe/result_after.txt` 14 / 0 (the final build, after the review): SF-FILE - an own
`LONGFI~1.TXT` with the server's content, `longfilename.txt` unchanged, no question; SF-HELD -
"Cannot download ...: the local name is the short name of another entry, which could not be moved
aside: (32) ...", no question, `longfilename.txt` unchanged; SF-MOVE / SF-MOVEHELD (F6, added after
the review) - the own file and the source gone / the error and the source still on the server;
SF-DIR - an own folder `LONGDI~1` with `a.txt`, `longdirname` holds only `keep.txt`; SF-DIRHELD
(`keep.txt` held, so `longdirname` cannot be moved aside) - "Cannot create directory ...: ... (5)",
nothing downloaded into `longdirname`; SF-DIRSAME - `longdirname\keep.txt` unchanged. Regression:
133's SFTP probe 76 / 0 (`probe/regress_133.txt`). FTP: not driven - owed to a person with an FTP
server (download a file `LONGFI~1.TXT` and a folder `LONGDI~1` next to `longfilename.txt` /
`longdirname`, once with the other entry held open).

## Review

Refute-first review: sound, no CRITICAL - no SFTP or FTP path left where a proven alias is
overwritten, resumed, joined or replaced, nor one where a refused local create lets a Move remove
the source (`xrFailed` before anything is written); after the core's move aside the failure path's
delete, the feature-138 bookkeeping and the move's size check reach the new file only; two remote
names `longfilename.txt` + `LONGFI~1.TXT` end as two local files; FTP's resume / overwrite / "use
existing dir" (also as queue ForceAction values) are reachable only through `alreadyExists`; the
helper cannot misfire on FAT, already-8.3 names, case or NFC / NFD; buffers fit; no code page.
Taken: (1) the error said no reason (the folder's was dropped) - now the core's step's reason in
the box and the log, through the existing `IDS_ERR_DOWNLOAD` / `IDS_ERR_MKDIR` (no new string);
(2) FTP's automatic rename would stop at the first round on a held alias - the name keeps counting
as taken (it is numbered), only `alreadyExists` is never set for it; the rows SF-MOVE /
SF-MOVEHELD added. NITs recorded: a path the helper cannot prove (not canonical, a folder that
cannot be listed) keeps the old handling; the helper repeats `SalNameIsOnlyShortNameOf` for
plug-ins without its own saltests check; extra lookups (SFTP asks the attributes twice; an existing
folder costs two searches); SFTP now shares the core's brief move aside of another folder in the
target (a remote `DOCUME~1` into a profile folder renames Documents aside for a moment - the
long-standing F5 behaviour).
