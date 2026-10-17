---
title: FTP against real servers: anonymous login, non-ASCII password, SOCKS 5 proxy
type: person-step
status: open
severity: 4
area: ftp
source: leftover:116
who: person
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [update-close-real-installer-signout-080-088-118]
depends-on: []
reason: -
---

# FTP against real servers: anonymous login, non-ASCII password, SOCKS 5 proxy

## Problem

FTP plug-in features 090 (anonymous-login default), 116 (FTP passwords) and 121 (FTP's welcome-message window declared for the update close) owe checks that need a real FTP server, a SOCKS 5 proxy, a Master Password or a real keyboard.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'The features' own quickstart.md person steps' ('090 (one anonymous FTP login against a server log)', '116 (the proxy server dialog, a Master Password, a real FTP server)', '121 (... FTP's welcome-message window)') and §B 'Environment or hardware' ('a SOCKS 5 proxy (116)') (at 7993914c). Steps: specs/090-ftp-anonymous-default/quickstart.md 'Owed to a person' 1-2; specs/116-ftp-passwords/quickstart.md 'Owed to a person (optional)'; specs/121-small-batch/quickstart.md 'By hand (a person, optional)'.

## Expected

Each step as its quickstart says; results in each fix-log.

## Notes

116's quickstart marks its person steps optional; its probe left four NOT DRIVEN rows (the proxy server dialog among them). Feature 178's caption row (`GetCommonFSOperSourceDescr`, the FTP upload of one local file with a long name; `specs/178-fsoper-descr-long-name/fix-log.md` L11: "Not driven: no FTP server on this machine (a person step: upload one file with a long accented name, look at the operation window's caption)") was added by the migration review (`specs/242-backlog-system/ledger/review.md`, S1).

Also owed with a real FTP server: (1) Feature 157: `ExpandPluralBytesFilesDirs` returns UTF-8, so the information line about selected files no longer reads "bajt? v 3 vybran?ch souborech"; the line draws itself and exposes no text to a probe. (2) Feature 205: FTP downloads never write into another entry by its 8.3 short name; SFTP was measured (4 / 4 -> 14 / 0), FTP was not driven (no FTP server). Evidence: Migrated from specs/NEXT-WORK.md §A item 10a (L275) and item 11 (L304) (at 7993914c). specs/157-ftp-infoline-plural/fix-log.md ("Owed to a person: an FTP panel with a bytes column, three files selected, Czech UI"); specs/205-download-short-name-clash/fix-log.md ("FTP: not driven - owed to a person with an FTP server"). Expected: The Czech line reads with its accented letters; each download lands under its own name and the neighbouring entry is untouched (or an error names the problem).

And: rows of features 134 / 136 not driven (feature 136 drove the bookmark dialogs, the password prompt, the login error and Save log - all pass), and the person's check owed by 235 after the withdrawn "tree download left nothing on disk" note. Evidence: Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L618-621 and L689-690. `specs/136-ftp-verify-rows/fix-log.md`, section 3; `specs/233-ftp-long-server-paths/`, feature 235. Expected: Each row reads correctly in Czech; a tree download from a real server leaves its files on disk.

## Steps

- [ ] 090: Plugins > FTP Client > Configuration shows anonymous@example.com on an untouched configuration; one anonymous login to a server whose own log shows PASS anonymous@example.com
- [ ] 116: a real keyboard pass (Czech and a non-Latin layout, an IME) in the Connect dialog and the login-error dialog; Show password with a Master Password set
- [ ] 116: the proxy server dialog; a SOCKS 5 proxy entry with a password over 255 bytes (e.g. 130 Czech letters) - OK says 'too long'
- [ ] 116: a real FTP server that accepts a non-ASCII password (vsftpd / FileZilla Server with a UTF-8 account)
- [ ] 121: a connection whose server sends a welcome message (the window open), then start an update (or rm_probe.ps1 -ExePath <exe>) - it closes; with the panel still connected the update declines (080 D7)
- [ ] Czech UI, an FTP panel with a bytes column, three files selected: the information line reads correctly (no '?')
- [ ] Download a file `LONGFI~1.TXT` from the server into a local folder that holds `longfilename.txt`: `longfilename.txt` keeps its content, the download is stored under its own name or refused with a message
- [ ] Download a folder `LONGDI~1` into a local folder that holds `longdirname`: nothing is written into `longdirname`
- [ ] Repeat both with the local entry held open by another program: no loss, an error names the problem
- [ ] Copy log (clipboard) - the pasted text is readable
- [ ] Proxy and server-type lists show their texts correctly
- [ ] FTPS certificate text
- [ ] Wait windows
- [ ] A tree download from a real FTP server leaves the files on disk (233/235: the earlier failure was a probe defect)
- [ ] 178: upload one local file whose name is longer than 259 bytes of UTF-8 (about 130 Czech letters) - the operation window's caption shows the name whole, cut (if at all) only at a whole letter (specs/178-fsoper-descr-long-name/fix-log.md L11)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — migration review S1/N3: row of 178 (upload caption with a long name) added; merge remarks reworded
- 2026-10-17 — related item real-keyboard-ime-pass-093-124-130 closed: done: steps carried out by hand by the maintainer before the 0.1.10 release; maintainer 2026-10-17
