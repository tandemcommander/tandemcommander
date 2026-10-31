# Data model - feature 362

## Folder file entry (UDF, ECMA-167 4/14.9 / 4/14.17)

| Field | Where | Use here |
|---|---|---|
| ICB tag flags & 7 | +16+18 | descriptor type: 0 short, 1 long, 2 extended, 3 embedded, 4 - 7 reserved (refused, 361) |
| L_EA | +168 (EFE +208) | start of the descriptor area |
| L_AD | +172 (EFE +212) | length of the descriptor area / embedded data; **0 for a folder = damaged (362)** |

## The reader's result (`ReadFileEntry(..., maxAds 1)`)

| Result | Meaning | Folder walkable (362) |
|---|---|---|
| 1 | one descriptor stored | yes |
| -1 | embedded data, area non-empty | yes |
| 0 | no descriptor (L_AD 0, any valid type) | **no** - unreadable folder |
| -2 (`UDF_FE_REFUSED`) | refused (361) | no |

## Outcome of "not walkable" (existing, feature 330)

- root: "Bad root ICB", `ListingLeftOut` incomplete;
- sub-folder: listed, not descended, `ListingLeftOut` incomplete - a whole unpack fails, the image is kept.
