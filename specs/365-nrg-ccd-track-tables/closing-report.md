# Closing report - 365-nrg-ccd-track-tables
Backlog item: iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables - ISO plug-in: NRG ETNF / ETN2 and multi-session CCD track tables get wrong sector sizes or ends
Outcome: closed

## What changed

- `src/common/salnrgcdtext.h`: Nero's verified mode table (`SalNrgModeVerified`, `SalNrgEtnSectorSize` - 0x00 /
  0x02 -> 2048, 0x03 -> 2336, 0x05 / 0x06 / 0x07 -> 2352; any other mode keeps its earlier size), ETNF / ETN2
  entry decoding (`SalNrgEtnDecode`), `SalNrgEtnEnd` (start + length, capped), `SalNrgEtnExtent` (review 1: the
  first-sector field relative to the image's first ETN2 track), `SalNrgEtnEntryCount`, `SalNrgEtn2ChunkPlausible`
  (at most 99 entries).
- `src/common/salisotrack.h`: `SalIsoCcdSectorCount` (a negative count -> 0, reported) and `SalIsoCcdTocLayout`
  (the CloneCD layout from the table of contents: each track's session and extent from its ADR-1 entry, its
  end at the next track or the session's lead-out, the sessions one after another in the `.img`; not
  followed when the table is incomplete or contradictory).
- `src/plugins/uniso/nrg.cpp`: `readETNF` sector size by mode; `readETN2` reads every whole entry (mode,
  size, header size, end, extent), skips a chunk outside the image or over 99 entries, continues after it.
- `src/plugins/uniso/img.cpp`: `ReadSessionCCD` uses the table-of-contents layout when it can be followed,
  else the earlier `INDEX 1 = 0` split with signed sector counts; an inconsistent table marks the listing
  incomplete; 352's sections / sessions mark unchanged.
- `src/saltests/saltests.cpp`: `TestNrgEtn365`, `TestIsoCcdToc365` (+102 checks).
- No UI string, dialog, menu, registry, installer or plug-in interface change.

## Measurements (before / after, commands)

`iso365_probe` on the hidden desktop (`powershell -File tools\run_on_hidden_desktop.ps1 ... iso365_probe.ps1
-Exe build\tandemcommander\Debug_x64\tandemcommander.exe`), seeds `mkimg365.sh` (genisoimage; session 2
addressed 11400 sectors after session 1), images `img365.py`, a whole Unpack with "Delete archive after
unpacking":

- before (41f18c08): **12 PASS / 6 FAIL** - R-ETNF05 / R-ETNF06 session 2 lost; R-ETN200 / R-ETN203 / R-ETN206
  session 2 lost and `Session 01/a.txt` written with session 2's bytes; R-CCDABS one session; all kept.
- after: 18 / 0; after review 1 (two rows added): **22 PASS / 0 FAIL**.
- Finding: CloneCD's own form (INDEX counted from the session, C-CCDREL) was already read correctly at
  41f18c08 - the item's "real multi-session image has absolute INDEX 1" premise is doubtful (libmirage,
  psx-spx, DiscImageCreator issue 121); both forms are now read alike.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64) -> `BUILD SUCCEEDED`, no warning in the changed files.
- saltests 29,791 -> **29,893 checks, 0 failed**; seven mutants (ETNF bit 0, ETN2 end = length, no 99 bound,
  unclamped count, no points-count check, no session order, lead-out of any session) fail 1 to 9 checks each.
- Regressions: 352 21 / 1 (R-ABS now extracts both sessions and deletes the image - the item's note; R-TWOSEC
  still kept), 351 10 / 0, 334 23 / 1 (S-RAW, recorded), 335 28 / 4 (Form 2 rows, recorded), 353 16 / 0.
- Every probe restored the registry key byte-identical.

## Reviews (findings and what was done)

- Review 1 (refute-first, independent agent): no MUST. Negative control: `main`'s `uniso.spl` 12 / 6 row for row,
  HEAD 18 / 0. SHOULD 1 - the ETN2 extent from the first-sector field (libmirage never reads it) made a
  one-session image with a field of 150 unopenable: fixed (`SalNrgEtnExtent`, probe rows R-ETN2ONE150 /
  R-ETN2150). SHOULD 2 - libmirage subtracts a stored pregap of INDEX 1 - INDEX 0; the docs said "PLBA alone":
  corrected, the limit recorded. NOTEs: `Start` capped (taken); the image-information reader's out-of-range
  session read reached also through ETN2 (logged on Inbox item
  `iso-plug-in-the-image-information-of-an-nrg-image-reads-past`); others accepted (fix-log *Review*).

## Owed to a person (with the new person-step items)

- `check-feature-365-with-real-nero-tao-and-clonecd-multi` - real Nero track-at-once (one and two sessions)
  and CloneCD dumps (two sessions, CD-Extra): every session listed and unpacked, the image deleted only then.
- The CHANGELOG entry below (`CHANGELOG.md` has no `## [Unreleased]` section - the tree is at the released
  0.2.0; the run does not create one). Entry to add under the next version's heading:

  ```text
  - **A Nero (.nrg) or CloneCD (.img) disc image of several sessions was listed without its second session, and a file could be extracted with the wrong content** (feature 365).
    - **Before:** in a Nero image burnt track-at-once, a raw (2352-byte) or Mode 2 data track was read with the wrong sector size, and an image with an ETN2 track table read only its first track entry, from the wrong place on the disc - the second session was not listed, and a file of the first session could be extracted with bytes of the second. A CloneCD image whose track positions count from the start of the disc was read as one session. "Delete archive after unpacking" kept these images, so nothing was deleted.
    - **Now:** the sector size follows the track's mode, every track entry of the table is read with its own mode, start, end and disc position, and a CloneCD image is split into sessions by its table of contents - every session is listed and extracted with the right content. A table that cannot be read consistently keeps the image after a whole unpack. Nero images of the oldest format (v1) and tracks stored with subchannel data are not yet read this way.
  ```

## New Inbox items (slug - title)

- `iso-plug-in-an-nrg-image-of-nero-v1-nero-footer-is-opened` - ISO plug-in: an NRG image of Nero v1 (NERO footer) is opened without its track table
- `iso-plug-in-nrg-tracks-of-the-subchannel-modes-0x0f-0x10` - ISO plug-in: NRG tracks of the subchannel modes 0x0F / 0x10 / 0x11 get a wrong type or size
- `check-feature-365-with-real-nero-tao-and-clonecd-multi` - Check feature 365 with real Nero TAO and CloneCD multi-session dumps (person step)
