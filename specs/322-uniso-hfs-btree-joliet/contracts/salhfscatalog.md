# Contract - `src/common/salhfscatalog.h` (feature 322)

Internal to the ISO plug-in and `saltests`; not part of the plug-in interface.

```cpp
#define SAL_HFSCAT_OK 0
#define SAL_HFSCAT_NOT_HEADER 1 // the first node is not a header node
#define SAL_HFSCAT_DAMAGED 2    // a node, link, size or record offset outside the catalog; a cycle
#define SAL_HFSCAT_NOMEM 3

struct SalHfsCatalogRecordRef { size_t Offset; size_t Avail; };

// Walks the leaf chain of an HFS+ B-tree loaded whole into data[0..size). On OK *records is a
// malloc'd array of *count references (NULL when 0) - free() it; on any other result *records is
// NULL and *count 0. Never reads outside data[0..size); always returns.
int SalHfsCatalogWalk(const unsigned char* data, size_t size,
                      SalHfsCatalogRecordRef** records, int* count);

struct SalHfsCatalogKey { unsigned KeyLength; unsigned NameLength; size_t BodyOffset; size_t BodyAvail; };

// The key of a catalog leaf record of 'avail' bytes: FALSE when the key, its name or the record
// type does not fit. BodyOffset / BodyAvail: the record data after the key (BodyAvail >= 2).
bool SalHfsCatalogKeyView(const unsigned char* rec, size_t avail, SalHfsCatalogKey* key);
```

Callers: `CHFS::BTree::BTree` (walk), `CHFS::BTree::GetRecord` (returns the record and its
`Avail`), `CHFS::GetRootName`, `CHFS::ListDirectory`, `CHFS::UnpackFile` (key view + body size).
