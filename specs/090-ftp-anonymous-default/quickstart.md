# Quickstart: verifying feature 090

| What | How | Expected |
|---|---|---|
| unit tests | `saltests.exe` | 0 failed (`TestFtpAnon090`) |
| source scan | `grep -rn someserver src help translations PRIVACY.md` | only `SAL_FTP_ANONYMOUS_OLD_DEFAULT` in `src/common/salftpanon.h` and its test |

## Owed to a person

1. *Plugins ▸ FTP Client ▸ Configuration*: the field *Password for anonymous
   connections* shows `anonymous@example.com` on a configuration that never
   changed it.
2. An anonymous connection to a public server (the log shows
   `PASS anonymous@example.com`... the log hides passwords: check with the
   server's own log or a local test server).
