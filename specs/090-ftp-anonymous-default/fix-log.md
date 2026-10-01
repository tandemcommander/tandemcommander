# Fix log: feature 090 — FTP anonymous placeholder

Branch `090-ftp-anonymous-default`, based on `089-7zip-followups`. Decisions
by the author (maintainer away): `spec.md` *Clarifications*.

## What changed

- `src/common/salftpanon.h` (header-only, pure): `SAL_FTP_ANONYMOUS_DEFAULT`
  = `anonymous@example.com`, `SAL_FTP_ANONYMOUS_OLD_DEFAULT`,
  `SalFtpAnonymousOnLoad(stored)`.
- `src/plugins/ftp/ftp3.cpp`: the default in `CConfiguration`'s constructor.
- `src/plugins/ftp/ftp.cpp` `LoadConfiguration`: the stored value passes
  through the rule. No configuration version is needed: after the
  replacement the stored value no longer matches, so the rule is idempotent.
- `PRIVACY.md` (stored data, network, the "how 0.1.8 differs" paragraph),
  `CHANGELOG.md`.

## Evidence

| Check | Result |
|---|---|
| saltests | **2055 / 0** (2039 + `TestFtpAnon090`: the old placeholder in any case becomes the new one; 11 user-style values, including near misses, come back as the same pointer; idempotent) |
| Debug and full Release builds, encoding guard | succeeded, `TOTAL: 0` |
| built `ftp.spl` (Release) | contains `anonymous@example.com` once; the old string once (the recognition constant) |
| source scan | the old placeholder only in `salftpanon.h`, its test, a comment, `PRIVACY.md` and `CHANGELOG.md` |

## Independent review — ACCEPT

One SHOULD-FIX in the records (NEXT-WORK still listed F9 as open; no fix log
— both done here) and three NITs (the wording of SC-003 and of the
changelog, unused includes) — fixed. Confirmed by the reviewer: every reader
goes through `Config.GetAnonymousPasswd`; the registry value is read at one
place; bookmarks store only the *Anonymous* flag, never a copy of the
address; the plug-in neither validates the address nor compares it with the
default anywhere else; translations and the manual do not contain it.

## Owed to a person

`quickstart.md`: the field in the FTP configuration; one anonymous
connection against a server whose log shows the password received.

## Not verified here

No FTP server was driven: the plug-in is not reachable from the test
executable and a GUI connection was not attempted. The value sent is the one
`Config.GetAnonymousPasswd` returns (`fs2.cpp:430-518`), which the review
traced.
