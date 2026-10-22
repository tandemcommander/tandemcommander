# Data model - 308-pax-deep-unpack

- **Pass** (`CArchive::Listing`): TRUE while `ListArchive` builds the panel listing, FALSE in every
  extraction (`DoUnpackArchive`, `UnpackOneFile`).
- **Member name** (`SCommonHeader::Name`, UTF-8, `\`-separated, `NameFromPax` = it came from a PAX
  `path`).
- **Refused** (`SCommonHeader::NameRefused`, also `Ignored`): `NameFromPax` and not
  `SalPaxNameUsableU8(Name, IsDir, ListingPrefixLen, Listing)`.
  - listing: a component over 255 UTF-16 units, or the folder part (+ prefix) over 255 bytes, or a
    folder's name over 255 bytes with a folder part;
  - extraction: a component over 255 UTF-16 units only.
- **Operation result**: an extraction that met a refused member it was asked for -> FALSE (the rest
  extracted); the core then neither deletes the archive nor reports success.
