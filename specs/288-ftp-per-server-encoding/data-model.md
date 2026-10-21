# Data model: 288 - per-server FTP name encoding

## Server encoding state (`CFTPServerEnc`, ftputils.cpp; in memory)

| Field | Meaning |
|---|---|
| Host | the FTP server's host as the connection names it (not a proxy's); compared without ASCII case |
| Port | the FTP server's port |
| User | the user name; NULL, "" and "anonymous" are one user |
| SawUtf8 | a listing field with non-ASCII bytes was valid UTF-8 / WTF-8 |
| SawCodePage | a listing field or a 257 path with non-ASCII bytes was read in the code page |

Lifetime: created at the first lookup of its identity, never freed before the plug-in's release
(`FTPFreeServerEncodings`, ftp.cpp) - a pointer from a lookup stays valid. At most 1,000 servers.

## Code-page name (`CFTPCodePageName`, 224, now per server)

| Field | Meaning |
|---|---|
| Server | the `CFTPServerEnc` whose listing or reply gave the text |
| Kind | `FTPNAME_CODEPAGE` (a text the server gave in the code page) or `FTPNAME_SENTUTF8` (a non-ASCII path component this client sent the server in UTF-8 while it was unknown or legacy - review of 288) |
| Len, Name | the UTF-8 form of the text |

One hash table for all servers (a lookup compares the server too); at most 200,000 names in total.

## State (salftpsrvenc.h)

| SawUtf8 | SawCodePage | State | A new non-ASCII name goes |
|---|---|---|---|
| no | no | unknown | UTF-8 |
| yes | no | UTF-8 | UTF-8 |
| no | yes | legacy | code page (if it holds it exactly), except a name sent it in UTF-8 |
| yes | yes | mixed | UTF-8 |

A name that is (or contains as a component or leading part) a code-page name of the same server
goes in the code page in every state (if the code page holds it). Evidence only accumulates; a
state never goes back to unknown during the plug-in's life.
