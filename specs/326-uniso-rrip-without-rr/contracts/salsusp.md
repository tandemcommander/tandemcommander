# Contract - `src/common/salsusp.h` (feature 326)

Header-only, no globals, no Windows types; for the ISO plug-in (`iso9660.cpp`) and `saltests`.
Internal to the program (not part of the plug-in interface).

```cpp
// The System Use area of an ISO 9660 directory record: the bytes after the file identifier and
// its padding byte (when the identifier's length is even), up to the record's length.
// rec = the record's first byte, avail = bytes readable from rec. Returns false when the record's
// lengths do not fit avail (length < 34, length > avail, 33 + identifier length > length);
// otherwise *suOffset / *suLength (suLength may be 0).
bool SalSuspSystemUseArea(const unsigned char* rec, size_t avail, size_t* suOffset, size_t* suLength);

// true when su (len bytes) starts with a valid SUSP SP entry: 'S' 'P', length >= 7, length <= len,
// version 1, check bytes 0xBE 0xEF; *lenSkp = its LEN_SKP byte.
bool SalSuspIsSp(const unsigned char* su, size_t len, unsigned char* lenSkp);

// The root directory's first record ('.'): true when its System Use area starts with SP.
bool SalSuspRootHasSp(const unsigned char* rec, size_t avail, unsigned char* lenSkp);

// Where the Rock Ridge entries of a record's System Use area (su, len) start:
//  - its first entry (byte 0, a whole 4-byte header) is 'R' 'R'  -> true, *start = 0 (any volume);
//  - else the volume has SP (suspVolume) and lenSkp + 4 <= len    -> true, *start = lenSkp;
//  - else false (the plain ISO 9660 name).
bool SalSuspRockRidgeStart(const unsigned char* su, size_t len, bool suspVolume, unsigned lenSkp, size_t* start);
```

Never reads outside `[rec, rec + avail)` / `[su, su + len)`.
