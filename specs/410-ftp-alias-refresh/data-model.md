# Data model - 410-ftp-alias-refresh

No stored data. One pure decision (`src/common/salftproot.h`):

| Input | Meaning |
|---|---|
| user1, user2 | user of each root; `NULL` or `anonymous` = anonymous (case-sensitive otherwise) |
| port1, port2 | port text; `NULL` = `21`; compared as text (as `FTPHasTheSameRootPath` did) |
| hostsEqual | the caller's host comparison (`SalamanderGeneral->StrICmp`, unchanged) |

| Result | When |
|---|---|
| `SAL_FTP_ROOT_SAME` | same user, same port, hosts equal |
| `SAL_FTP_ROOT_OTHER_HOST` | same user, same port, hosts differ - maybe the same server (341) |
| `SAL_FTP_ROOT_OTHER` | another user or another port |
