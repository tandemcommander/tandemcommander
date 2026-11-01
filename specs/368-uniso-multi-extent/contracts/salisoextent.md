# Contract - src/common/salisoextent.h (feature 368)

Header-only, no Windows dependency beyond `<cstddef>` / `<string>` / `<vector>`; used by the ISO plug-in
(`iso9660.cpp`, `isoimage.cpp`) and `saltests`. Internal to the product - not part of the plug-in interface.

```cpp
const unsigned SAL_ISO_FILE_FLAG_DIRECTORY = 0x02;
const unsigned SAL_ISO_FILE_FLAG_MULTI_EXTENT = 0x80;

struct SalIsoExtent { unsigned long Location; unsigned long Length; };

// a record continues its file in the next record: a file record (not a folder) with bit 7
bool SalIsoRecordContinues(unsigned flags);

// the sectors an extent of 'length' bytes spans (2048-byte logical blocks, rounded up; 0 for 0)
unsigned long long SalIsoExtentSectors(unsigned long long length);
// the file bytes sector 'sector' (0-based) of that extent holds: 2048, or the rest in its last sector
unsigned long SalIsoExtentSectorBytes(unsigned long long length, unsigned long long sector);
// the file size: the sum of the lengths
unsigned long long SalIsoExtentsSize(const SalIsoExtent* e, size_t n);

// the chain state of one directory walk and its decision per record
struct SalIsoExtentChain { bool Open; size_t FirstOffset; std::string Id; std::vector<SalIsoExtent> Extents; };
#define SAL_ISO_CHAIN_LIST 0       // list the record as it is (folder, or a file of one extent)
#define SAL_ISO_CHAIN_HELD 1       // the record belongs to the open chain; nothing listed yet
#define SAL_ISO_CHAIN_DONE 2       // the chain ended with this record: list it (named by FirstOffset's record)
// *broke = true when an open chain was broken by this record (report it; the record then gets its own action).
// May throw std::bad_alloc (the caller treats it as out of memory).
int SalIsoChainRecord(SalIsoExtentChain& c, size_t offset, const unsigned char* id, size_t idLen, unsigned flags,
                      unsigned long location, unsigned long length, bool* broke);
// the directory ended: true when a chain was still open (broken); the chain is closed
bool SalIsoChainEnd(SalIsoExtentChain& c);

// may a chain be listed: every extent in the track of the first (trackOf), at or after that track's extent
// offset, its sectors within 32-bit sector numbers, and the first track not storing Form 2 data
template <class TrackOf, class TrackOffset>
bool SalIsoChainReadable(const SalIsoExtent* e, size_t n, int trackCount, TrackOf trackOf, TrackOffset offsetOf,
                         bool firstTrackStoresForm2);
```

Invariants (saltests `TestIsoMultiExtent_368`): a file record without the bit outside a chain is LIST; a chain is
listed only when its last record (same identifier, bit clear) is met; any other record or the directory's end
breaks it; a folder with the bit is LIST; the read plan of an extent writes exactly its length; sizes above 4 GiB do
not wrap.
