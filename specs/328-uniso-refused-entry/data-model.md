# Data model - feature 328

- **CSalListingLeftOut** (`src/common/salisonamefit.h`): `Count` (entries left out), `Paths` (the
  first 10 in-image paths, whole, without the leading `\`), `Incomplete` (a listing left something
  out - also set by a core refusal that is not the rule's). `Text(errText)` -> the report:
  `errText` + `\n\n` + paths joined by `\n` + `\n...` when `Count > 10`.
- **Walk modes of CISO9660** (members): `FitCheck` (count walk: nothing added), `FitIsoNames`
  (count walk lists Rock Ridge records under their ISO 9660 names), `FitCount` (entries the count
  walk would list), `FitRefused` (some entry refused), `Decide` (listing in decision mode).
- **CPluginDataInterface::ListingLeftOut**: the listing behind this plug-in data left entries out -
  `UnpackWholeArchive` fails.
