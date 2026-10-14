# Fix log: 188 - Dropbox and Google Drive are found under an account name with diacritics

Backlog: NEXT-WORK section D, "A shell calls that return paths (128)": `SHGetFolderPath` A in
`drivelst.cpp` / `shiconov.cpp`.

## Read (not driven: this machine's account name is ASCII; no profile was made for the test)

`InitDropboxPath` (`drivelst.cpp`) and `GetGoogleDrivePath` (`shiconov.cpp`) got `%APPDATA%`,
`%LOCALAPPDATA%` and the profile folder from `SHGetFolderPath` A - code page - and handed them to
`FileExists` (the UTF-8 facade): under an account named with diacritics (also Czech ones in code
page 1250) the configuration files were never found - no cloud-folder icon overlays, the Google
Drive default path in code page. The same defect 069 (F-P1-08) fixed for the configuration folder.

## Work

- `src/salamdr5.cpp` `SalGetFolderPathU8` (declared in `consts.h`): `SHGetFolderPathW` + UTF-8,
  never cut.
- `src/drivelst.cpp` `InitDropboxPath`: UTF-8 paths of 3 x MAX_PATH bytes, `host.db` opened with
  `SalCreateFile`.
- `src/shiconov.cpp` `GetGoogleDrivePath`: UTF-8 paths; sqlite opens the UTF-8 path directly (it was
  the code-page path converted through UTF-16); the default "Google Drive" folder in UTF-8.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0. Owed to a person: an account with a name like
"Šárka" with Dropbox / Google Drive installed - the overlay icons on their folders.

## Review

Quick refute-first review: sound - sizes (the inner `DropboxPath` / `GoogleDrivePath` stay
MAX_PATH and refuse a longer value, never cut), handle pairing, no code-page consumer left (the
OneDrive producer was UTF-8 since 069). Taken: a stale trace text. Recorded: the 069 helpers for
the roaming folder could use `SalGetFolderPathU8` (cleanup only).
