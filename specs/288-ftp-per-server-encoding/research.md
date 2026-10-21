# Research: 288 - per-server FTP name encoding

## R1 Evidence: listings and 257 replies, no FEAT

- **Decision**: UTF-8 evidence = a non-ASCII listing field that is valid UTF-8 / WTF-8
  (`SalFtpListingFieldIsU8`, 269); legacy evidence = a non-ASCII listing field or 257 path read in
  the code page. A 257 path that is valid UTF-8 is not evidence.
- **Rationale**: the plug-in sends no `FEAT`; adding it is a change of network communication
  (maintainer-owned). A 257 reply (PWD after a CWD, MKD) may echo the client's own bytes - a path
  typed while the state was unknown went in UTF-8 and would come back "valid UTF-8".
- **Alternatives**: send `FEAT` and read ` UTF8` (WinSCP, FileZilla) - recorded as a decision item;
  `OPTS UTF8 ON` - same; a per-bookmark encoding setting - stored data + UI, maintainer-owned.

## R2 Server identity

- **Decision**: host compared without ASCII case, port equal, user equal byte for byte with
  NULL / "" / "anonymous" (`FTP_ANONYMOUS`) the same - the rule of the upload listing cache
  (`CUploadListingCache::FindServer`, operats9.cpp).
- **Rationale**: the panel's connection and an operation's workers use different spellings of the
  anonymous user (the operation stores "anonymous"); the cache already relies on this identity.
- **Alternatives**: the server's IP address - not known everywhere, a proxy hides it.

## R3 State and decision

- **Decision**: unknown (no evidence) / UTF-8 / legacy / mixed (both). Code page when the name is
  one of the server's code-page names (component or leading part, 224) or the state is legacy;
  and only when the code page holds it (`WideCharToMultiByte` without the default character, as 224).
- **Rationale**: keeps 224's policy for unknown and mixed servers (UTF-8 for new names); a legacy
  server gets its encoding. Mixed servers (byte-transparent servers holding both kinds) cannot be
  decided for a new name - UTF-8, the modern default.

## R4 Plumbing

- **Decision**: explicit server parameter for `PrepareFTPCommand` (first parameter; every one of
  the 57 call sites updated - the compiler finds each, a `char*` buffer does not convert to the
  server pointer), `FTPU8NameToServer`, `FTPGetDirectoryFromReply` (4 callers). The listing parser
  (`AssignStringToColumn` deep inside `CFTPParser::GetNextItemFromListing`) gets the server from a
  scoped thread-local (`CFTPListingServerScope`) set by the four parse loops' owners:
  `CPluginFSInterface::ParseListing` (fs2.cpp), `CFTPWorker::ParseListingToFTPQueue` (operats6.cpp),
  `CUploadListingsOnServer` around `CUploadPathListing::ParseListing` (operats9.cpp, 3 sites); the
  server-type test dialog (dialogs4.cpp) sets none (no evidence).
- **Rationale**: the parser's column functions are shared and many levels deep; a thread-local
  scope is local to the four loops and nests (restores the previous value). Commands are explicit
  so no site can be missed silently.
- **Alternatives**: a thread-local for commands too - a forgotten site would silently use the
  wrong server; a parameter through the parser - touches every parser function.
- Server state objects live until the plug-in is released, so a pointer obtained for one call
  stays valid; each site looks the server up again (no cached pointer in the sockets - the user of
  a connection may change at login).

## R5 Found on the way (outside the scope)

- `ctrlcon5.cpp` calls `UploadListingCache.ReportCreateDirs(hostBuf, userBuffer, ...)` and
  `ReportRename(hostBuf, userBuffer, ...)` while the functions take `(user, host, ...)`: the panel's
  Create Directory and Quick Rename never update the upload listing cache (FindServer never
  matches). Recorded as an Inbox item, not fixed here.
