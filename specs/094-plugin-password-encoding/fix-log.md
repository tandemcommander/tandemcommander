# Fix log: feature 094 - ZIP and SFTP password forms

Branch `094-plugin-password-encoding`, from `main` (492aca7a).
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T001 - measurement

See `research.md`. In short: neither plug-in has the 7zip plug-in's defect.
ZIP reads the field through the code page: a password outside the code page
is used as `?` characters (confirmed through the product); archives keyed
with UTF-8 bytes never open; AES archives keyed with OEM bytes do not open.
SFTP sends exact UTF-8 below 512 bytes and code-page bytes at or above.
FTP: UTF-8 bytes verbatim, not changed.
