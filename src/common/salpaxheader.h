// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpaxheader.h
//
// The records of a PAX extended header (POSIX.1-2001 tar, feature 306).
// Header-only, no globals; for the tar plug-in and saltests.
//
// A PAX tar puts a member's real path, size and time into an extended header -
// type 'x' for the next member, type 'g' for every following member - and
// leaves only a fallback in the ustar header: the name cut at 100 bytes,
// non-ASCII letters as '?', size 0 for 8 GiB and more, the time rounded. The
// tar plug-in skipped both header types and listed / extracted the fallback.
//
// The data of an extended header is a sequence of records
//     "<length> <keyword>=<value>\n"
// where <length> (decimal) counts the whole record, itself and the newline
// included. An empty value cancels the keyword: in an 'x' header the global
// value does not apply to that member, in a 'g' header the global value is
// dropped. The last record of a keyword wins. A member's own value beats the
// global one; both beat the ustar header and a GNU long name.
//
// Applied keywords: path, size, mtime, linkpath (feature 309: the name a hard or
// symbolic link refers to). Everything else is ignored (uname, comment, SCHILY.*, ...).
//
// Errors: a malformed record, an invalid size or a NUL inside a path make the
// header BAD - the caller refuses the archive (a wrong size or name would
// misread or misname every later member). An invalid or unrepresentable mtime
// is ignored: the ustar time stays.
//
//*****************************************************************************

#include <stdlib.h>
#include <string.h>

#include "salmaskname.h" // SAL_NAME_MAX_UTF16_UNITS, SalMaskNameDetail::CharLen

#define SAL_PAX_OK 0
#define SAL_PAX_BAD 1   // malformed record or value
#define SAL_PAX_NOMEM 2 // out of memory

#define SAL_PAX_UNSET 0
#define SAL_PAX_DELETED 1 // "keyword=" - no value (falls back to the global / ustar value)
#define SAL_PAX_SET 2

// an extended header with more data refuses the archive (records are short; this bounds the buffer)
#define SAL_PAX_MAX_HEADER_BYTES (1024 * 1024)

// mtime range a FILETIME holds: 1601-01-01 .. the largest second whose 100-ns count fits 63 bits
#define SAL_PAX_MTIME_MIN (-11644473600LL)
#define SAL_PAX_MTIME_MAX (910692730085LL)
// the 100-ns units that still fit in that last second: 2^63 - 1 - (MAX + 11644473600) * 10^7 (review 2)
#define SAL_PAX_MTIME_MAX_FRAC 4775807u

struct SalPaxValues
{
    int PathState;
    char* Path; // malloc'd, NUL-terminated: the value's bytes (UTF-8 by the standard)
    int LinkPathState; // feature 309
    char* LinkPath;    // malloc'd, NUL-terminated, as Path
    int SizeState;
    unsigned __int64 Size;
    int MTimeState;
    __int64 MTimeSec;       // seconds since 1970-01-01 UTC, rounded down
    unsigned int MTimeFrac; // 100-ns units within that second, 0..9999999
};

inline void SalPaxInit(SalPaxValues* v)
{
    memset(v, 0, sizeof(*v));
}

inline void SalPaxClear(SalPaxValues* v)
{
    free(v->Path);
    free(v->LinkPath);
    SalPaxInit(v);
}

// SalPaxValues that frees itself (the values of one header chain)
struct CSalPaxValuesHolder
{
    SalPaxValues V;
    CSalPaxValuesHolder() { SalPaxInit(&V); }
    ~CSalPaxValuesHolder() { SalPaxClear(&V); }
    CSalPaxValuesHolder(const CSalPaxValuesHolder&) = delete;
    CSalPaxValuesHolder& operator=(const CSalPaxValuesHolder&) = delete;
};

// the record at data[*pos]: 1 = a record (*pos moves past it), 0 = the end (nothing or only NUL
// bytes left - some writers pad the data), -1 = malformed
inline int SalPaxNextRecord(const char* data, size_t size, size_t* pos, const char** key, size_t* keyLen,
                            const char** val, size_t* valLen)
{
    size_t p = *pos;
    size_t q = p;
    while (q < size && data[q] == 0)
        q++;
    if (q >= size)
    {
        *pos = size;
        return 0;
    }
    size_t len = 0;
    size_t i = p;
    while (i < size && data[i] >= '0' && data[i] <= '9')
    {
        len = len * 10 + (size_t)(data[i] - '0');
        if (len > size) // longer than the whole data (also guards the multiplication)
            return -1;
        i++;
    }
    if (i == p || i >= size || data[i] != ' ')
        return -1;
    // the shortest record after the length and the space: "k=\n"
    if (len > size - p || len < (i - p) + 1 + 3)
        return -1;
    size_t end = p + len;
    if (data[end - 1] != '\n')
        return -1;
    const char* k = data + i + 1;
    const char* recEnd = data + end - 1; // the newline
    const char* eq = (const char*)memchr(k, '=', (size_t)(recEnd - k));
    if (eq == NULL || eq == k)
        return -1;
    *key = k;
    *keyLen = (size_t)(eq - k);
    *val = eq + 1;
    *valLen = (size_t)(recEnd - (eq + 1));
    *pos = end;
    return 1;
}

// a PAX size: 1..19 decimal digits, at most 2^63-1
inline bool SalPaxParseSize(const char* s, size_t n, unsigned __int64* out)
{
    if (n == 0 || n > 19)
        return false;
    unsigned __int64 v = 0;
    for (size_t i = 0; i < n; i++)
    {
        if (s[i] < '0' || s[i] > '9')
            return false;
        v = v * 10 + (unsigned __int64)(s[i] - '0'); // 19 digits fit 64 bits unsigned
    }
    if (v > 0x7FFFFFFFFFFFFFFFULL)
        return false;
    *out = v;
    return true;
}

// a PAX time "[-]digits[.digits]": 1 = valid (seconds rounded down + 100-ns fraction; digits
// beyond the seventh are dropped), 0 = valid but outside SAL_PAX_MTIME_MIN..MAX, -1 = malformed
inline int SalPaxParseTime(const char* s, size_t n, __int64* sec, unsigned int* frac)
{
    size_t i = 0;
    bool neg = false;
    if (i < n && s[i] == '-')
    {
        neg = true;
        i++;
    }
    size_t intStart = i;
    unsigned __int64 whole = 0;
    while (i < n && s[i] >= '0' && s[i] <= '9')
    {
        if (i - intStart >= 18) // more than 18 digits: far outside any FILETIME
        {
            while (i < n && s[i] >= '0' && s[i] <= '9')
                i++;
            if (i < n && s[i] == '.')
            {
                i++;
                while (i < n && s[i] >= '0' && s[i] <= '9')
                    i++;
            }
            return i == n ? 0 : -1;
        }
        whole = whole * 10 + (unsigned __int64)(s[i] - '0');
        i++;
    }
    if (i == intStart)
        return -1;
    unsigned int f = 0;
    if (i < n && s[i] == '.')
    {
        i++;
        int digits = 0;
        while (i < n && s[i] >= '0' && s[i] <= '9')
        {
            if (digits < 7)
            {
                f = f * 10 + (unsigned int)(s[i] - '0');
                digits++;
            }
            i++;
        }
        while (digits < 7)
        {
            f *= 10;
            digits++;
        }
    }
    if (i != n)
        return -1;
    __int64 v = (__int64)whole; // at most 18 digits: fits
    if (neg)
    {
        v = -v;
        if (f != 0)
        {
            v -= 1;
            f = 10000000 - f;
        }
    }
    if (v < SAL_PAX_MTIME_MIN || v > SAL_PAX_MTIME_MAX || (v == SAL_PAX_MTIME_MAX && f > SAL_PAX_MTIME_MAX_FRAC))
        return 0;
    *sec = v;
    *frac = f;
    return 1;
}

namespace SalPaxDetail
{
    inline bool KeyIs(const char* key, size_t keyLen, const char* name)
    {
        size_t n = strlen(name);
        return keyLen == n && memcmp(key, name, n) == 0;
    }
} // namespace SalPaxDetail

// applies the records of one extended header's data to 'v' (an 'x' header: the next member's
// values; a 'g' header: the global ones); SAL_PAX_OK / SAL_PAX_BAD / SAL_PAX_NOMEM
inline int SalPaxApply(const char* data, size_t size, SalPaxValues* v)
{
    size_t pos = 0;
    for (;;)
    {
        const char* key;
        size_t keyLen;
        const char* val;
        size_t valLen;
        int r = SalPaxNextRecord(data, size, &pos, &key, &keyLen, &val, &valLen);
        if (r == 0)
            return SAL_PAX_OK;
        if (r < 0)
            return SAL_PAX_BAD;
        bool isPath = SalPaxDetail::KeyIs(key, keyLen, "path");
        if (isPath || SalPaxDetail::KeyIs(key, keyLen, "linkpath")) // feature 309: linkpath as path
        {
            char** dst = isPath ? &v->Path : &v->LinkPath;
            int* state = isPath ? &v->PathState : &v->LinkPathState;
            if (valLen == 0)
            {
                free(*dst);
                *dst = NULL;
                *state = SAL_PAX_DELETED;
                continue;
            }
            if (memchr(val, 0, valLen) != NULL)
                return SAL_PAX_BAD; // a name cannot hold a NUL - it would be cut at it
            char* p = (char*)malloc(valLen + 1);
            if (p == NULL)
                return SAL_PAX_NOMEM;
            memcpy(p, val, valLen);
            p[valLen] = 0;
            free(*dst);
            *dst = p;
            *state = SAL_PAX_SET;
        }
        else if (SalPaxDetail::KeyIs(key, keyLen, "size"))
        {
            if (valLen == 0)
            {
                v->SizeState = SAL_PAX_DELETED;
                continue;
            }
            unsigned __int64 sz;
            if (!SalPaxParseSize(val, valLen, &sz))
                return SAL_PAX_BAD;
            v->Size = sz;
            v->SizeState = SAL_PAX_SET;
        }
        else if (SalPaxDetail::KeyIs(key, keyLen, "mtime"))
        {
            if (valLen == 0)
            {
                v->MTimeState = SAL_PAX_DELETED;
                continue;
            }
            __int64 sec;
            unsigned int frac;
            if (SalPaxParseTime(val, valLen, &sec, &frac) == 1)
            {
                v->MTimeSec = sec;
                v->MTimeFrac = frac;
                v->MTimeState = SAL_PAX_SET;
            } // otherwise ignored: the ustar time stays (as Python and GNU tar do)
        }
    }
}

// the member's path: its own value, else the global one; NULL = the ustar / GNU name stays
inline const char* SalPaxEffectivePath(const SalPaxValues* global, const SalPaxValues* member)
{
    if (member->PathState == SAL_PAX_SET)
        return member->Path;
    if (member->PathState == SAL_PAX_DELETED)
        return NULL;
    return global->PathState == SAL_PAX_SET ? global->Path : NULL;
}

// feature 309: the name a link member refers to - its own value, else the global one; NULL = the GNU
// long link name / ustar link name stays
inline const char* SalPaxEffectiveLinkPath(const SalPaxValues* global, const SalPaxValues* member)
{
    if (member->LinkPathState == SAL_PAX_SET)
        return member->LinkPath;
    if (member->LinkPathState == SAL_PAX_DELETED)
        return NULL;
    return global->LinkPathState == SAL_PAX_SET ? global->LinkPath : NULL;
}

inline bool SalPaxEffectiveSize(const SalPaxValues* global, const SalPaxValues* member, unsigned __int64* out)
{
    const SalPaxValues* v = member->SizeState != SAL_PAX_UNSET ? member : global;
    if (v->SizeState != SAL_PAX_SET)
        return false;
    *out = v->Size;
    return true;
}

inline bool SalPaxEffectiveMTime(const SalPaxValues* global, const SalPaxValues* member, __int64* sec,
                                 unsigned int* frac)
{
    const SalPaxValues* v = member->MTimeState != SAL_PAX_UNSET ? member : global;
    if (v->MTimeState != SAL_PAX_SET)
        return false;
    *sec = v->MTimeSec;
    *frac = v->MTimeFrac;
    return true;
}

// true when a component of 'path' (separated by '/' or '\\', UTF-8) has more UTF-16 units than
// any Windows file system stores (the rule of SalNameUtf16UnitsU8 / SalNameTooLongForFileSystemU8)
inline bool SalPaxPathHasTooLongComponentU8(const char* path)
{
    int units = 0;
    while (*path != 0)
    {
        if (*path == '/' || *path == '\\')
        {
            units = 0;
            path++;
            continue;
        }
        int len = SalMaskNameDetail::CharLen(path); // a separator is never a continuation byte
        units += len == 4 ? 2 : 1;
        if (units > SAL_NAME_MAX_UTF16_UNITS)
            return true;
        path += len;
    }
    return false;
}

// the panel listing's own limits (CSalamanderDirectory::AddFile / AddDir, src/zip.cpp, feature 222):
// the folder part of a member's path and a folder's own name hold at most MAX_PATH - 5 BYTES. A
// member over them makes AddFile / AddDir fail, and the archive plug-in then gives up the WHOLE
// listing - so such a member is refused alone (review 1 of feature 306: a PAX path deeper than the
// ustar fallback could ever be made an archive unopenable that the fallback names left openable)
#define SAL_PAX_LISTING_MAX_BYTES (MAX_PATH - 5)

// true when the listing can hold the member 'name' (components separated by '\\' or '/', no leading
// or trailing separator; 'isDir' = a folder member) and no component is too long for a file system;
// 'prefixLen' = bytes the listing puts before every member's folder part (review 2: a .deb lists
// its two tar parts under "control\" and "data\")
inline bool SalPaxNameFitsListingU8(const char* name, bool isDir, size_t prefixLen = 0)
{
    if (SalPaxPathHasTooLongComponentU8(name))
        return false;
    const char* last = NULL; // the last separator
    for (const char* s = name; *s != 0; s++)
        if (*s == '\\' || *s == '/')
            last = s;
    size_t folderPart = last != NULL ? (size_t)(last - name) : 0;
    if (prefixLen + folderPart > SAL_PAX_LISTING_MAX_BYTES)
        return false;
    if (isDir && strlen(last != NULL ? last + 1 : name) > SAL_PAX_LISTING_MAX_BYTES)
        return false;
    return true;
}

// true when the member 'name' can be used in the current pass over the archive (feature 308): while
// the panel listing is built ('listing'), the listing's bounds above apply; an extraction takes every
// name a file system takes - depth is the file system's business (long paths), only a component over
// 255 UTF-16 units is refused. The listing bound in an extraction left deep members out of a whole
// unpack that still succeeded, and "Delete archive after unpacking" then deleted the archive.
inline bool SalPaxNameUsableU8(const char* name, bool isDir, size_t prefixLen, bool listing)
{
    if (listing)
        return SalPaxNameFitsListingU8(name, isDir, prefixLen);
    return !SalPaxPathHasTooLongComponentU8(name);
}
