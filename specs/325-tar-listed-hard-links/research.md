# Research - 325-tar-listed-hard-links

## R1 - List or report?

- Decision: list hard links as files and extract them from the target's data.
- Rationale: the item's first alternative; fixes Copy of selected files, Copy of one focused name and
  F3 alike. A report of left-out links would leave the names missing.
- Alternatives: report the link members "next to" the selected names - needs a guess of what the
  user meant (select one file -> a message about another), still loses the names.

## R2 - Getting the target's data when the target is not selected

- Decision: a second pass over a reopened stream, only when a deferred link exists; it stops after
  the last wanted data member.
- Rationale: a tar link always names an earlier member; the single forward pass has passed the data
  by the time the link is read. `CDecompressFile` cannot seek back (gzip / bzip2 / xz decode
  forward), but `CreateInstance(fileName, offset, size)` opens the same (sub)stream again - the .deb
  sub-archives included (offset + size kept by `CArchive`).
- Alternatives: (a) carry the link -> target map from the listing in `CFileData::PluginData` - needs a
  plug-in data interface for every listed file, and a Copy started without a listing (Unpack with a
  mask) would still miss it; (b) a pre-scan of the headers before every extraction - pays the second
  read on every Copy; (c) extracting every unasked data member into a temporary file - unbounded disk.

## R3 - Which cases change

- Decision: only a hard link whose target was not asked for (or is itself deferred). A target asked
  but not written (Skip, refused name) is reported as in 309; symbolic links stay unlisted and
  reported when asked (309).
- Rationale: §1 step 4 - keep every case the item does not name.

## R4 - Several deferred links to one target; chains

- Decision: resolve each deferred link through the map of every hard link of pass 1 (bounded by its
  size: a cycle is unresolved); group by data name; the data is written under the first link's name,
  the others are copies of it (`WriteOutLinkCopy`, identity check). If the user skips the first, the
  others are reported (the data is read once).
- Listing: the same resolution over the links listed so far; size of the data member, else 0.

## R5 - One file (F3 / disk cache)

- Decision: `UnpackOneFile` of a hard link resolves it with the links and data names seen before it;
  then reopens the stream and extracts the data member under `newFileName` or the link's file name.
  An unresolvable link is reported as in 309.
