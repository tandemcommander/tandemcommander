# Backlog — run journal

One row per run of `/tandem-backlog-implement`, newest last, appended by
`python tools/backlog/backlog.py run-log`. Outcomes: `closed`, `blocked`,
`not-reproduced`, `split`, `nothing-to-do`.

| Date | Item | Outcome | Feature | Branch | Inbox | Person steps | Note |
|---|---|---|---|---|---|---|---|
| 2026-10-18 12:59 | vkladanie-zo-schranky-nefunguje-v-adresaroch-s-v-ceste | not-reproduced | - | - | 0 | - | cause was the 0.1.9 code-page copy-name word (error 123), fixed by feature 127; not the exclamation mark |
| 2026-10-19 23:15 | drobna-chyba-textu-v-hlavicce-pro-zobrazeni-plochy-v-cestine | closed | 248 | 248-folders-column-names | 2 | answer and close GitHub issue #13 (draft in specs/248-folders-column-names/reply.md) | Desktop view column headers (Folders plug-in) handed to the core in the code page instead of UTF-8; cut at a whole character |
