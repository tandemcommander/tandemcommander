---
title: PictView by hand: own camera photos, pipette, histogram, one print
type: person-step
status: open
severity: 5
area: pictview
source: leftover:135
who: person
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [pictview-update-thumbnail-142-leftovers]
depends-on: []
reason: -
---

# PictView by hand: own camera photos, pipette, histogram, one print

## Problem

Several PictView checks need a real mouse, a printer or the user's own photos and could not be driven on the hidden desktop: Update Thumbnail on a few of the maintainer's own camera photos (135 measured 91 public samples; 'a look at a few own photos in the program is all that is left' - listed first of the steps owed before 0.1.10), the pipette and histogram rows of 120 (a real mouse on an unlocked visible desktop), one real print compared with its preview (152), and the two WebDAV rename rows of 111 that were NOT DRIVEN in the 0.1.10 closing pass because the WebClient service was not running (starting it needs an administrator).

## Evidence

Migrated from specs/NEXT-WORK.md header, 'Before 0.1.10 - steps owed to a person' point 1, the 'Closing pass on this state (2026-10-14, commit 4c852fe9)' paragraph, and §B 'By hand' / 'The features' own quickstart.md person steps' (at 7993914c). Sources: specs/135-pictview-real-photos/fix-log.md ('Owed to a person, now a formality: Update Thumbnail on a few own photos', ~line 74); specs/120-pictview-leftovers/quickstart.md 'By hand (Release build, a real mouse) - owed' rows 1-4; specs/152-pictview-print-preview/fix-log.md ~line 74 ('Owed to a person: print once ... and compare the paper with' the preview); specs/179-pictview-print-fit/fix-log.md ('Owed to a person (with 152's step)', NW §A item 6a L245); 111 rows: the regression probe of specs/111-pictview-shown-image (WebDAV rename rows).

## Expected

Each step below done on a Release build and its result recorded in the feature's fix-log (135, 120, 152, 111); any failure becomes a new item.

## Notes

First of the four person steps owed before 0.1.10 (`backlog/RELEASE.md`, *Current release*) and, in NEXT-WORK's words, "the one that matters": 135 measured the maker's block of real camera files unchanged (82 of 82; 91 public samples), a look at a few own photos in the program is left. Feature 179 (print with *Scale to fit*: no mirroring by a stored negative `Width` / `Height`, no 32-bit wrap at a large scale; `specs/179-pictview-print-fit/fix-log.md`, "Owed to a person (with 152's step)") owes one print as well - one print session serves 152 and 179. The code leftovers of 142 around Update Thumbnail are `pictview-update-thumbnail-142-leftovers`. 120's quickstart lists two more by-hand rows (Rename between two windows, full-screen background after a rotation); NEXT-WORK names only the pipette and histogram rows.

## Steps

- [ ] 135: Update Thumbnail on a few own camera photos (JPEG with maker notes): the photos open, the new thumbnail shows, the picture and its Exif data / maker notes stay intact; record in specs/135-pictview-real-photos/fix-log.md
- [ ] 120 row 1: F3 on a photo, Tools > Pipette - the colour shown matches the pixel under the cursor (compare with a paint program); mirror horizontally - still the pixel under the cursor (specs/120-pictview-leftovers/quickstart.md, 'By hand')
- [ ] 120 row 2: File > Histogram of a photo - a plausible curve; of a one-colour image - one bar per channel
- [ ] 152 and 179: print once (a printer or Microsoft Print to PDF) and compare the paper with the preview - plain, mirrored, a selection; then with Fit on after a negative width was typed (also with a selection and with a mirror) - the paper is upright like the preview in every case
- [ ] 111: start the WebClient service (administrator), re-run the two WebDAV rename rows of 111's probe that were NOT DRIVEN in the 0.1.10 closing pass

## Log

- 2026-10-13 — feature 135 measured 82 of 82 real camera files unchanged in the maker's block
- 2026-10-14 — 0.1.10 closing pass (commit 4c852fe9): two 111 rows (WebDAV rename) NOT DRIVEN - the WebClient service was not running after a restart
- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — moved to Person steps position 1
- 2026-10-17 — migration review M1/N1/N3: first of the four steps owed before 0.1.10; duplicate Update Thumbnail and print steps merged (152 + 179 in one); migration remarks replaced
- 2026-10-17 — related: kept to the 142 leftovers
