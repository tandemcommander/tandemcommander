# Data model - 332-uniso-hfs-skipped-records

## HFS+ catalog leaf record (TN1150, big-endian)

| Bytes | Field |
|---|---|
| 0-1 | keyLength (the key is keyLength + 2 bytes; >= 6) |
| 2-5 | parentID (1 = the root folder's parent) |
| 6-7 | nodeName.length (UTF-16 units; 0 for a thread) |
| 8.. | nodeName.unicode |
| 2 + keyLength .. | record data: recordType (1 folder, 2 file, 3 folder thread, 4 file thread), then the structure (folder 88 bytes, file 248 bytes, type included) |

## Record class (`SalHfsCatalogRecordClass`, checked in this order)

| Condition | Class | Listing |
|---|---|---|
| key / name / type does not fit the record | DAMAGED | skipped, marked |
| parent 1 and the volume label is in use | NOT_ENTRY | skipped |
| empty name: thread type, or parent 1 | NOT_ENTRY | skipped |
| empty name otherwise | DAMAGED | skipped, marked |
| name over 255 units | DAMAGED | skipped, marked |
| folder, data under 88 bytes / file, data under 248 bytes | DAMAGED | skipped, marked |
| any other type, name starting with U+0000 | DAMAGED | skipped, marked |
| any other type | UNKNOWN | marked, the HFS+ listing ends |
| folder in the root (parent 2) named exactly "<4 x U+0000>HFS+ Private Data" | NOT_ENTRY | skipped (HFS+ metadata) |
| any other folder / file whose name starts with U+0000 | DAMAGED | skipped, marked (review 1) |
| folder / file | FOLDER / FILE | listed (329's rules follow) |

`hfs.cpp` adds: a FOLDER / FILE whose name does not convert to UTF-8 - skipped, marked.

## Listing incomplete mark

Feature 328's `CISOImage::ListingLeftOut.Incomplete`; `ListArchive` copies it to the plug-in data,
`UnpackWholeArchive` then returns FALSE (the image is kept).
