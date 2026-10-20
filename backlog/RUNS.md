# Backlog — run journal

One row per run of `/tandem-backlog-implement`, newest last, appended by
`python tools/backlog/backlog.py run-log`. Outcomes: `closed`, `blocked`,
`not-reproduced`, `split`, `nothing-to-do`.

| Date | Item | Outcome | Feature | Branch | Inbox | Person steps | Note |
|---|---|---|---|---|---|---|---|
| 2026-10-18 12:59 | vkladanie-zo-schranky-nefunguje-v-adresaroch-s-v-ceste | not-reproduced | - | - | 0 | - | cause was the 0.1.9 code-page copy-name word (error 123), fixed by feature 127; not the exclamation mark |
| 2026-10-19 23:15 | drobna-chyba-textu-v-hlavicce-pro-zobrazeni-plochy-v-cestine | closed | 248 | 248-folders-column-names | 2 | answer and close GitHub issue #13 (draft in specs/248-folders-column-names/reply.md) | Desktop view column headers (Folders plug-in) handed to the core in the code page instead of UTF-8; cut at a whole character |
| 2026-10-19 23:47 | temp-dir-walks-follow-junctions | closed | 249 | 249-temp-walks-junctions | 1 | - | external unpacker walk refuses a restored junction on the archive path; 212 sweep driven; selfextr source fixed |
| 2026-10-20 00:17 | a-damaged-highlighting-entry-hangs-the-program-at-start-up | closed | 250 | 250-damaged-highlight-entry | 2 | - | the highlighting-list loader skips a damaged entry instead of re-opening it forever; probe 28/0 |
| 2026-10-20 01:49 | dialog-typed-text-cut-to-caller-buffer | closed | 251 | 251-dialog-text-fits | 1 | - | typed text that does not fit the buffer is refused, never cut: Make File List, user menu, viewers, editors, hot paths, drives, Edit New default, browse buttons |
| 2026-10-20 01:56 | ftp-long-name-and-path-leftovers | split | - | - | 4 | triage four new Inbox items, among them the decision ftp-escaped-path-does-not-fit-decision | split into 4: PWD and path cuts, escape decision, local long paths, mask by server encoding |
| 2026-10-20 02:03 | uniso-hfs-btree-trust-and-joliet-cut | blocked | - | - | 0 | decide how to continue the item (by hand) | stopped during the measurement before specify; Joliet cut and HFS+ B-tree trust confirmed by reading at a7eb2296 |
