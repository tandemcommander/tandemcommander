# Data model - 368-uniso-multi-extent

## SalIsoExtent (src/common/salisoextent.h)

| Field | Type | Meaning |
|---|---|---|
| Location | unsigned long | the extent's first sector (disc address, as the record stores it) |
| Length | unsigned long | the record's data length in bytes |

## SalIsoExtentChain (src/common/salisoextent.h) - the open chain of a directory walk

| Field | Meaning |
|---|---|
| Open | a record with the multi-extent bit was met and its chain has not ended |
| FirstOffset | the offset of the chain's first record in the directory data (it names the file) |
| Id | the raw identifier of the first record (bytes) |
| Extents | the extents met so far, in record order |

States per record (`SalIsoChainRecord`):

| Chain | Record | Action |
|---|---|---|
| closed | folder, or file without the bit | LIST (as before) |
| closed | file with the bit | HELD (chain opened with its extent) |
| open | file of the same identifier with the bit | HELD (extent appended) |
| open | file of the same identifier without the bit | CHAIN_DONE (extent appended; the chain is listed) |
| open | another identifier, or a folder | the chain BROKEN (reported), then the record by the closed rows |
| open | the directory ends | BROKEN (reported) |

## CISOImage::CFilePos (uniso) - added

| Field | Meaning |
|---|---|
| Extents | owned array of the file's extents, NULL for a single-extent file |
| ExtentCount | number of entries of Extents (0 for a single-extent file) |

`Extent` stays the first extent (track selection, stream coverage). Size of the listed file = sum of the lengths.
