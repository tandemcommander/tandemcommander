// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcfgimport.h
//
// Pure rules of the settings import from Altap Salamander 2.5-4.0 and Open
// Salamander 5.0 (feature 245). Header-only, no globals, no registry access,
// no STL: the core, plug-ins and saltests use it (contract
// specs/245-*/contracts/salcfgimport-rules.md).
//
// The core reads the chosen source root ONCE, read-only, into a snapshot tree
// (CSalCfgKey); everything here works on that tree, so the source registry is
// never touched again and the rules can be checked with in-memory fixtures.
// Strings are UTF-8 (WTF-8): the reader converts REG_SZ from UTF-16; binary
// values are kept byte for byte.
//
//*****************************************************************************

#include <windows.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

//
// ****************************************************************************
// Snapshot tree
//

struct CSalCfgValue
{
    char* Name;  // UTF-8
    DWORD Type;  // REG_SZ, REG_DWORD, REG_BINARY, ...
    BYTE* Data;  // Size bytes + two zero bytes (strings are always NUL-terminated)
    DWORD Size;  // for REG_SZ/REG_EXPAND_SZ: bytes of the UTF-8 text incl. its terminator
};

struct CSalCfgKey
{
    char* Name; // UTF-8
    CSalCfgValue* Values;
    int ValueCount;
    int ValueCap;
    CSalCfgKey** Keys;
    int KeyCount;
    int KeyCap;
    BOOL Truncated; // the reader left out something of THIS key (a value or a subkey)
};

namespace SalCfgImpDetail
{
    inline char AsciiLower(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c + ('a' - 'A')) : c; }

    // registry names here are ASCII; non-ASCII bytes compare exactly
    inline BOOL NameEqCI(const char* a, const char* b)
    {
        if (a == NULL || b == NULL)
            return FALSE;
        while (*a != 0 && *b != 0)
        {
            if (AsciiLower(*a) != AsciiLower(*b))
                return FALSE;
            a++;
            b++;
        }
        return *a == 0 && *b == 0;
    }

    inline BOOL NameEqCIn(const char* a, int aLen, const char* b)
    {
        int i;
        for (i = 0; i < aLen; i++)
        {
            if (b[i] == 0 || AsciiLower(a[i]) != AsciiLower(b[i]))
                return FALSE;
        }
        return b[aLen] == 0;
    }

    inline char* Dup(const char* s)
    {
        if (s == NULL)
            s = "";
        size_t l = strlen(s) + 1;
        char* d = (char*)malloc(l);
        if (d != NULL)
            memcpy(d, s, l);
        return d;
    }

    inline BOOL Copy(char* out, int outSize, const char* s)
    {
        if (out == NULL || outSize <= 0)
            return FALSE;
        size_t l = strlen(s);
        if ((int)l >= outSize)
        {
            out[0] = 0;
            return FALSE;
        }
        memcpy(out, s, l + 1);
        return TRUE;
    }

    // length of the longest prefix of 's' not longer than 'maxBytes' ending on a character boundary
    inline int Utf8Fit(const char* s, int maxBytes)
    {
        int l = (int)strlen(s);
        if (l <= maxBytes)
            return l;
        int n = maxBytes;
        while (n > 0 && (((unsigned char)s[n]) & 0xC0) == 0x80)
            n--;
        return n;
    }
} // namespace SalCfgImpDetail

// copies UTF-8 text 'src' to 'dst' (size 'size'); text that does not fit is cut after its last
// whole character (rules 097/098) - for report text and labels only, never for names or paths
inline void SalCfgImpCopyText(char* dst, int size, const char* src)
{
    if (dst == NULL || size < 1)
        return;
    if (src == NULL)
        src = "";
    int n = SalCfgImpDetail::Utf8Fit(src, size - 1);
    memmove(dst, src, n);
    dst[n] = 0;
}

// formats UTF-8 report text like _snprintf_s; text that does not fit is cut after its last
// whole character
inline void SalCfgImpFormatText(char* dst, int size, const char* fmt, ...)
{
    if (dst == NULL || size < 1)
        return;
    char big[4096];
    va_list args;
    va_start(args, fmt);
    int r = _vsnprintf_s(big, _TRUNCATE, fmt != NULL ? fmt : "", args);
    va_end(args);
    if (r < 0) // cut by _TRUNCATE: drop a split last character
    {
        int len = (int)strlen(big);
        int start = len - 1;
        while (start > 0 && (((unsigned char)big[start]) & 0xC0) == 0x80)
            start--;
        unsigned char lead = start >= 0 ? (unsigned char)big[start] : 0;
        int need = lead < 0x80 ? 1 : (lead & 0xE0) == 0xC0 ? 2
                                 : (lead & 0xF0) == 0xE0   ? 3
                                 : (lead & 0xF8) == 0xF0   ? 4
                                                           : 0;
        if (start >= 0 && len - start != need)
            big[start] = 0; // incomplete (or invalid) last sequence
    }
    SalCfgImpCopyText(dst, size, big);
}

inline CSalCfgKey* SalCfgKeyNew(const char* name)
{
    CSalCfgKey* k = (CSalCfgKey*)calloc(1, sizeof(CSalCfgKey));
    if (k == NULL)
        return NULL;
    k->Name = SalCfgImpDetail::Dup(name);
    if (k->Name == NULL)
    {
        free(k);
        return NULL;
    }
    return k;
}

inline void SalCfgKeyFree(CSalCfgKey* key)
{
    if (key == NULL)
        return;
    int i;
    for (i = 0; i < key->ValueCount; i++)
    {
        free(key->Values[i].Name);
        if (key->Values[i].Data != NULL)
        {
            SecureZeroMemory(key->Values[i].Data, key->Values[i].Size); // may hold password blobs
            free(key->Values[i].Data);
        }
    }
    free(key->Values);
    for (i = 0; i < key->KeyCount; i++)
        SalCfgKeyFree(key->Keys[i]);
    free(key->Keys);
    free(key->Name);
    free(key);
}

inline CSalCfgKey* SalCfgKeyAddKey(CSalCfgKey* parent, const char* name)
{
    if (parent == NULL || name == NULL)
        return NULL;
    if (parent->KeyCount == parent->KeyCap)
    {
        int cap = parent->KeyCap == 0 ? 8 : parent->KeyCap * 2;
        CSalCfgKey** n = (CSalCfgKey**)realloc(parent->Keys, cap * sizeof(CSalCfgKey*));
        if (n == NULL)
            return NULL;
        parent->Keys = n;
        parent->KeyCap = cap;
    }
    CSalCfgKey* k = SalCfgKeyNew(name);
    if (k == NULL)
        return NULL;
    parent->Keys[parent->KeyCount++] = k;
    return k;
}

inline BOOL SalCfgKeyAddValue(CSalCfgKey* key, const char* name, DWORD type, const void* data, DWORD size)
{
    if (key == NULL || name == NULL || (data == NULL && size != 0))
        return FALSE;
    if (key->ValueCount == key->ValueCap)
    {
        int cap = key->ValueCap == 0 ? 8 : key->ValueCap * 2;
        CSalCfgValue* n = (CSalCfgValue*)realloc(key->Values, cap * sizeof(CSalCfgValue));
        if (n == NULL)
            return FALSE;
        key->Values = n;
        key->ValueCap = cap;
    }
    CSalCfgValue* v = &key->Values[key->ValueCount];
    v->Name = SalCfgImpDetail::Dup(name);
    v->Data = (BYTE*)calloc(1, (size_t)size + 2);
    if (v->Name == NULL || v->Data == NULL)
    {
        free(v->Name);
        free(v->Data);
        return FALSE;
    }
    if (size != 0)
        memcpy(v->Data, data, size);
    v->Type = type;
    v->Size = size;
    key->ValueCount++;
    return TRUE;
}

inline BOOL SalCfgKeyAddString(CSalCfgKey* key, const char* name, const char* text)
{
    return SalCfgKeyAddValue(key, name, REG_SZ, text, (DWORD)strlen(text) + 1);
}

inline BOOL SalCfgKeyAddDword(CSalCfgKey* key, const char* name, DWORD value)
{
    return SalCfgKeyAddValue(key, name, REG_DWORD, &value, sizeof(DWORD));
}

inline const CSalCfgKey* SalCfgKeyFindChild(const CSalCfgKey* key, const char* name)
{
    if (key == NULL || name == NULL)
        return NULL;
    int i;
    for (i = 0; i < key->KeyCount; i++)
    {
        if (SalCfgImpDetail::NameEqCI(key->Keys[i]->Name, name))
            return key->Keys[i];
    }
    return NULL;
}

// subkey by a path "A\B\C" (empty path = 'key' itself)
inline const CSalCfgKey* SalCfgKeyFind(const CSalCfgKey* key, const char* path)
{
    if (key == NULL || path == NULL)
        return NULL;
    const char* s = path;
    while (*s != 0 && key != NULL)
    {
        const char* e = strchr(s, '\\');
        int len = e != NULL ? (int)(e - s) : (int)strlen(s);
        const CSalCfgKey* found = NULL;
        int i;
        for (i = 0; i < key->KeyCount; i++)
        {
            if (SalCfgImpDetail::NameEqCIn(s, len, key->Keys[i]->Name))
            {
                found = key->Keys[i];
                break;
            }
        }
        key = found;
        s += len;
        if (*s == '\\')
            s++;
    }
    return key;
}

// TRUE when the reader left out something of 'key' or of any key below it
inline BOOL SalCfgKeySubtreeTruncated(const CSalCfgKey* key)
{
    if (key == NULL)
        return FALSE;
    if (key->Truncated)
        return TRUE;
    int i;
    for (i = 0; i < key->KeyCount; i++)
    {
        if (SalCfgKeySubtreeTruncated(key->Keys[i]))
            return TRUE;
    }
    return FALSE;
}

inline const CSalCfgValue* SalCfgValueFind(const CSalCfgKey* key, const char* name)
{
    if (key == NULL || name == NULL)
        return NULL;
    int i;
    for (i = 0; i < key->ValueCount; i++)
    {
        if (SalCfgImpDetail::NameEqCI(key->Values[i].Name, name))
            return &key->Values[i];
    }
    return NULL;
}

inline BOOL SalCfgGetDword(const CSalCfgKey* key, const char* name, DWORD* value)
{
    const CSalCfgValue* v = SalCfgValueFind(key, name);
    if (v == NULL || v->Type != REG_DWORD || v->Size != sizeof(DWORD))
        return FALSE;
    memcpy(value, v->Data, sizeof(DWORD));
    return TRUE;
}

// NULL when absent or not a string value
inline const char* SalCfgGetString(const CSalCfgKey* key, const char* name)
{
    const CSalCfgValue* v = SalCfgValueFind(key, name);
    if (v == NULL || (v->Type != REG_SZ && v->Type != REG_EXPAND_SZ))
        return NULL;
    return (const char*)v->Data; // always NUL-terminated (two zero bytes behind the data)
}

inline const BYTE* SalCfgGetBinary(const CSalCfgKey* key, const char* name, DWORD type, DWORD* size)
{
    const CSalCfgValue* v = SalCfgValueFind(key, name);
    if (v == NULL || v->Type != type)
        return NULL;
    if (size != NULL)
        *size = v->Size;
    return v->Data;
}

//
// ****************************************************************************
// Sources
//

#define SALCFGIMP_SUPPORTED 0
#define SALCFGIMP_TOO_OLD 1 // older than Altap Salamander 2.5 (configuration version < 39)
#define SALCFGIMP_TOO_NEW 2 // written by a newer program than this one

#define SALCFGIMP_MIN_CONFIG_VERSION 39 // Altap Salamander 2.5

// the configuration roots of the old programs, newest first (from the product's own list
// before feature 032: git show afcaa9eb -- src/mainwnd2.cpp)
inline const char* SalCfgImpRoot(int index)
{
    static const char* const roots[] = {
        "Software\\Open Salamander\\5.0",
        "Software\\Altap\\Altap Salamander 4.0",
        "Software\\Altap\\Altap Salamander 4.0 beta 1 (DB177)",
        "Software\\Altap\\Altap Salamander 4.0 beta 1 (DB171)",
        "Software\\Altap\\Altap Salamander 3.08",
        "Software\\Altap\\Altap Salamander 4.0 beta 1 (DB168)",
        "Software\\Altap\\Altap Salamander 3.07",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB162)",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB159)",
        "Software\\Altap\\Altap Salamander 3.06",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB153)",
        "Software\\Altap\\Altap Salamander 3.05",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB147)",
        "Software\\Altap\\Altap Salamander 3.04",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB141)",
        "Software\\Altap\\Altap Salamander 3.03",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB135)",
        "Software\\Altap\\Altap Salamander 3.02",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB129)",
        "Software\\Altap\\Altap Salamander 3.01",
        "Software\\Altap\\Altap Salamander 3.1 beta 1 (DB123)",
        "Software\\Altap\\Altap Salamander 3.0",
        "Software\\Altap\\Altap Salamander 3.0 beta 5 (DB117)",
        "Software\\Altap\\Altap Salamander 3.0 beta 4",
        "Software\\Altap\\Altap Salamander 3.0 beta 4 (DB111)",
        "Software\\Altap\\Altap Salamander 3.0 beta 3",
        "Software\\Altap\\Altap Salamander 3.0 beta 3 (DB105)",
        "Software\\Altap\\Altap Salamander 3.0 beta 3 (PB103)",
        "Software\\Altap\\Altap Salamander 3.0 beta 3 (DB100)",
        "Software\\Altap\\Altap Salamander 3.0 beta 2",
        "Software\\Altap\\Altap Salamander 3.0 beta 2 (DB94)",
        "Software\\Altap\\Altap Salamander 3.0 beta 1",
        "Software\\Altap\\Altap Salamander 3.0 beta 1 (DB88)",
        "Software\\Altap\\Altap Salamander 3.0 beta 1 (PB87)",
        "Software\\Altap\\Altap Salamander 3.0 beta 1 (DB83)",
        "Software\\Altap\\Altap Salamander 3.0 beta 1 (DB80)",
        "Software\\Altap\\Altap Salamander 3.0 beta 1 (PB79)",
        "Software\\Altap\\Altap Salamander 3.0 beta 1 (DB76)",
        "Software\\Altap\\Altap Salamander 3.0 beta 1 (PB75)",
        "Software\\Altap\\Altap Salamander 2.55 beta 1 (DB 72)",
        "Software\\Altap\\Altap Salamander 2.54",
        "Software\\Altap\\Altap Salamander 2.54 beta 1 (DB 66)",
        "Software\\Altap\\Altap Salamander 2.53",
        "Software\\Altap\\Altap Salamander 2.53 (DB 60)",
        "Software\\Altap\\Altap Salamander 2.53 beta 2",
        "Software\\Altap\\Altap Salamander 2.53 beta 2 (IB 55)",
        "Software\\Altap\\Altap Salamander 2.53 (DB 52)",
        "Software\\Altap\\Altap Salamander 2.53 beta 1",
        "Software\\Altap\\Altap Salamander 2.53 beta 1 (DB 46)",
        "Software\\Altap\\Altap Salamander 2.53 beta 1 (PB 44)",
        "Software\\Altap\\Altap Salamander 2.53 beta 1 (DB 41)",
        "Software\\Altap\\Altap Salamander 2.53 beta 1 (DB 39)",
        "Software\\Altap\\Altap Salamander 2.53 beta 1 (PB 38)",
        "Software\\Altap\\Altap Salamander 2.53 beta 1 (DB 36)",
        "Software\\Altap\\Altap Salamander 2.53 beta 1 (DB 33)",
        "Software\\Altap\\Altap Salamander 2.52",
        "Software\\Altap\\Altap Salamander 2.52 (DB 30)",
        "Software\\Altap\\Altap Salamander 2.52 beta 2",
        "Software\\Altap\\Altap Salamander 2.52 beta 1",
        "Software\\Altap\\Altap Salamander 2.51",
        "Software\\Altap\\Altap Salamander 2.5",
        "Software\\Altap\\Altap Salamander 2.5 RC3",
        "Software\\Altap\\Servant Salamander 2.5 RC3",
        "Software\\Altap\\Servant Salamander 2.5 RC2",
        "Software\\Altap\\Servant Salamander 2.5 RC1",
        "Software\\Altap\\Servant Salamander 2.5 beta 12",
        "Software\\Altap\\Servant Salamander 2.5 beta 11",
        "Software\\Altap\\Servant Salamander 2.5 beta 10",
        "Software\\Altap\\Servant Salamander 2.5 beta 9",
        "Software\\Altap\\Servant Salamander 2.5 beta 8",
        "Software\\Altap\\Servant Salamander 2.5 beta 7",
        "Software\\Altap\\Servant Salamander 2.5 beta 6",
        "Software\\Altap\\Servant Salamander 2.5 beta 5",
        "Software\\Altap\\Servant Salamander 2.5 beta 4",
        "Software\\Altap\\Servant Salamander 2.5 beta 3",
        "Software\\Altap\\Servant Salamander 2.5 beta 2",
        "Software\\Altap\\Servant Salamander 2.5 beta 1",
        "Software\\Altap\\Servant Salamander 2.1 beta 1",
        "Software\\Altap\\Servant Salamander 2.0",
        "Software\\Altap\\Servant Salamander 1.6 beta 7",
        "Software\\Altap\\Servant Salamander 1.6 beta 6",
        "Software\\Altap\\Servant Salamander",
        "Software\\Salamander",
    };
    if (index < 0 || index >= (int)(sizeof(roots) / sizeof(roots[0])))
        return NULL;
    return roots[index];
}

inline int SalCfgImpRootCount()
{
    int n = 0;
    while (SalCfgImpRoot(n) != NULL)
        n++;
    return n;
}

// a key of this program family that must never be offered as a source (also checked for test roots)
inline BOOL SalCfgImpIsForeignRootAllowed(const char* keyPath)
{
    if (keyPath == NULL || *keyPath == 0)
        return FALSE;
    const char* banned[] = {"Tandem Commander", "Newt Commander"};
    int b;
    for (b = 0; b < 2; b++)
    {
        size_t bl = strlen(banned[b]);
        const char* s;
        for (s = keyPath; *s != 0; s++)
        {
            if ((s == keyPath || s[-1] == '\\') && strlen(s) >= bl)
            {
                size_t i;
                BOOL eq = TRUE;
                for (i = 0; i < bl; i++)
                {
                    if (SalCfgImpDetail::AsciiLower(s[i]) != SalCfgImpDetail::AsciiLower(banned[b][i]))
                    {
                        eq = FALSE;
                        break;
                    }
                }
                if (eq && (s[bl] == 0 || s[bl] == '\\'))
                    return FALSE;
            }
        }
    }
    return TRUE;
}

inline int SalCfgImpClassify(DWORD cfgVer, DWORD thisVer)
{
    if (cfgVer < SALCFGIMP_MIN_CONFIG_VERSION)
        return SALCFGIMP_TOO_OLD;
    if (cfgVer > thisVer)
        return SALCFGIMP_TOO_NEW;
    return SALCFGIMP_SUPPORTED;
}

// the label of a root: its last path component ("Altap Salamander 4.0"); for "...\5.0" the
// two last components joined by a space ("Open Salamander 5.0")
inline BOOL SalCfgImpProductName(const char* keyPath, char* buf, int size)
{
    if (keyPath == NULL || buf == NULL || size <= 0)
        return FALSE;
    const char* last = strrchr(keyPath, '\\');
    const char* lastName = last != NULL ? last + 1 : keyPath;
    if (last != NULL && lastName[0] >= '0' && lastName[0] <= '9') // a bare version: prefix the product name
    {
        const char* prev = last;
        while (prev > keyPath && prev[-1] != '\\')
            prev--;
        int prodLen = (int)(last - prev);
        int verLen = (int)strlen(lastName);
        if (prodLen + 1 + verLen >= size)
        {
            buf[0] = 0;
            return FALSE;
        }
        memcpy(buf, prev, prodLen);
        buf[prodLen] = ' ';
        memcpy(buf + prodLen + 1, lastName, verLen + 1);
        return TRUE;
    }
    return SalCfgImpDetail::Copy(buf, size, lastName);
}

// < 0 when source A is to be listed before B (newer configuration first, ties by table order)
inline int SalCfgImpCompareSources(DWORD verA, int orderA, DWORD verB, int orderB)
{
    if (verA != verB)
        return verA > verB ? -1 : 1;
    return orderA - orderB;
}

//
// ****************************************************************************
// Conversions of old configuration versions
//

// "$" -> "$$" (hot paths of configurations older than 47); FALSE when it does not fit (never cut)
inline BOOL SalCfgImpDuplicateDollars(const char* in, char* out, int outSize)
{
    if (in == NULL || out == NULL || outSize <= 0)
        return FALSE;
    int o = 0;
    const char* s;
    for (s = in; *s != 0; s++)
    {
        int need = (*s == '$') ? 2 : 1;
        if (o + need >= outSize)
        {
            out[0] = 0;
            return FALSE;
        }
        out[o++] = *s;
        if (*s == '$')
            out[o++] = '$';
    }
    out[o] = 0;
    return TRUE;
}

// "$$" -> "$": the user-visible text of a stored hot path (CHotPathItems' rule)
inline BOOL SalCfgImpUnescapeDollars(const char* in, char* out, int outSize)
{
    if (in == NULL || out == NULL || outSize <= 0)
        return FALSE;
    int o = 0;
    const char* s = in;
    while (*s != 0)
    {
        if (s[0] == '$' && s[1] == '$')
            s++;
        if (o + 1 >= outSize)
        {
            out[0] = 0;
            return FALSE;
        }
        out[o++] = *s++;
    }
    out[o] = 0;
    return TRUE;
}

// ASCII letters to lower case (masks of configurations older than 44); other bytes unchanged
inline BOOL SalCfgImpLowerAscii(const char* in, char* out, int outSize)
{
    if (in == NULL || out == NULL || outSize <= 0)
        return FALSE;
    size_t l = strlen(in);
    if ((int)l >= outSize)
    {
        out[0] = 0;
        return FALSE;
    }
    size_t i;
    for (i = 0; i <= l; i++)
        out[i] = SalCfgImpDetail::AsciiLower(in[i]);
    return TRUE;
}

//
// ****************************************************************************
// Identities
//

namespace SalCfgImpDetail
{
    inline int __cdecl CmpStrPtr(const void* a, const void* b)
    {
        return strcmp(*(const char* const*)a, *(const char* const*)b);
    }
} // namespace SalCfgImpDetail

// the identity of a mask list: parts split at ';', spaces trimmed, ASCII lower case, empty
// parts dropped, sorted, duplicates dropped, joined by ';'
inline BOOL SalCfgImpMasksKey(const char* masks, char* out, int outSize)
{
    if (masks == NULL || out == NULL || outSize <= 0)
        return FALSE;
    size_t l = strlen(masks);
    char* work = (char*)malloc(l + 1);
    const char** parts = (const char**)malloc((l / 1 + 1) * sizeof(char*));
    if (work == NULL || parts == NULL)
    {
        free(work);
        free((void*)parts);
        out[0] = 0;
        return FALSE;
    }
    size_t i;
    for (i = 0; i <= l; i++)
        work[i] = SalCfgImpDetail::AsciiLower(masks[i]);
    int count = 0;
    char* s = work;
    while (TRUE)
    {
        char* e = strchr(s, ';');
        if (e != NULL)
            *e = 0;
        while (*s == ' ')
            s++;
        char* t = s + strlen(s);
        while (t > s && t[-1] == ' ')
            *--t = 0;
        if (*s != 0)
            parts[count++] = s;
        if (e == NULL)
            break;
        s = e + 1;
    }
    qsort((void*)parts, count, sizeof(char*), SalCfgImpDetail::CmpStrPtr);
    int o = 0;
    BOOL ok = TRUE;
    int k;
    for (k = 0; k < count; k++)
    {
        if (k > 0 && strcmp(parts[k], parts[k - 1]) == 0)
            continue;
        int pl = (int)strlen(parts[k]);
        int need = pl + (o > 0 ? 1 : 0);
        if (o + need >= outSize)
        {
            ok = FALSE;
            break;
        }
        if (o > 0)
            out[o++] = ';';
        memcpy(out + o, parts[k], pl);
        o += pl;
    }
    out[ok ? o : 0] = 0;
    free(work);
    free((void*)parts);
    return ok;
}

// removes trailing backslashes, keeping the roots "\", "X:\" and the "\\" prefix
inline BOOL SalCfgImpTrimTrailingSlash(const char* path, char* out, int outSize)
{
    if (!SalCfgImpDetail::Copy(out, outSize, path != NULL ? path : ""))
        return FALSE;
    int l = (int)strlen(out);
    while (l > 1 && out[l - 1] == '\\')
    {
        if (l == 3 && out[1] == ':') // "X:\"
            break;
        if (l == 2 && out[0] == '\\') // "\\"
            break;
        out[--l] = 0;
    }
    return TRUE;
}

typedef BOOL (*SalCfgImpExistsFn)(void* ctx, const char* name);

namespace SalCfgImpDetail
{
    // a format with exactly one "%d" and no other '%'
    inline BOOL IsSafeIndexFormat(const char* fmt)
    {
        if (fmt == NULL)
            return FALSE;
        int found = 0;
        const char* s;
        for (s = fmt; *s != 0; s++)
        {
            if (*s == '%')
            {
                if (s[1] == 'd' && found == 0)
                {
                    found = 1;
                    s++;
                }
                else
                    return FALSE;
            }
        }
        return found == 1;
    }
} // namespace SalCfgImpDetail

// the first of "base", "base <suffixFirst>", "base <suffixNthFmt % 2>", ... (up to 999) for
// which 'exists' says FALSE; a 'base' too long for 'outSize' with its suffix is shortened at a
// character boundary (these are labels, not paths); FALSE when nothing fits
inline BOOL SalCfgImpUniqueName(const char* base, const char* suffixFirst, const char* suffixNthFmt,
                                SalCfgImpExistsFn exists, void* ctx, char* out, int outSize)
{
    if (base == NULL || out == NULL || outSize < 2 || exists == NULL)
        return FALSE;
    if (!SalCfgImpDetail::IsSafeIndexFormat(suffixNthFmt))
        suffixNthFmt = "(%d)";
    if (suffixFirst == NULL)
        suffixFirst = "(2)";
    int n;
    for (n = 1; n <= 999; n++)
    {
        char suffix[100];
        if (n == 1)
            suffix[0] = 0;
        else if (n == 2)
            _snprintf_s(suffix, _TRUNCATE, " %s", suffixFirst);
        else
        {
            char num[64];
            _snprintf_s(num, _TRUNCATE, suffixNthFmt, n - 1);
            _snprintf_s(suffix, _TRUNCATE, " %s", num);
        }
        int sl = (int)strlen(suffix);
        if (sl >= outSize - 1)
            return FALSE;
        int bl = SalCfgImpDetail::Utf8Fit(base, outSize - 1 - sl);
        memcpy(out, base, bl);
        memcpy(out + bl, suffix, sl + 1);
        if (!exists(ctx, out))
            return TRUE;
    }
    out[0] = 0;
    return FALSE;
}

//
// ****************************************************************************
// Placement and merging
//

// the slot (0-based) an imported hot path goes to: its own slot when free, else the lowest
// free slot; -1 when all are occupied
inline int SalCfgImpPlaceHotPath(const BOOL* occupied, int count, int srcSlot)
{
    if (occupied == NULL || count <= 0)
        return -1;
    if (srcSlot >= 0 && srcSlot < count && !occupied[srcSlot])
        return srcSlot;
    int i;
    for (i = 0; i < count; i++)
    {
        if (!occupied[i])
            return i;
    }
    return -1;
}

// current entries first, then imported entries not present yet (exact compare, empty entries
// dropped), at most 'cap'; 'out' points into the inputs; returns the count
inline int SalCfgImpMergeHistory(const char* const* cur, int curCount, const char* const* imp, int impCount,
                                 const char** out, int cap)
{
    int n = 0;
    int i;
    for (i = 0; i < curCount && n < cap; i++)
    {
        if (cur[i] != NULL && cur[i][0] != 0)
            out[n++] = cur[i];
    }
    for (i = 0; i < impCount && n < cap; i++)
    {
        if (imp[i] == NULL || imp[i][0] == 0)
            continue;
        BOOL present = FALSE;
        int j;
        for (j = 0; j < n; j++)
        {
            if (strcmp(out[j], imp[i]) == 0)
            {
                present = TRUE;
                break;
            }
        }
        if (!present)
            out[n++] = imp[i];
    }
    return n;
}

// a per-drive default directory the program accepts: value name one letter A-Z, the path
// "X:\..." of the same letter, shorter than 'maxLen' (LoadConfig shows an error box otherwise)
inline BOOL SalCfgImpDefaultDirValid(const char* name, const char* value, int maxLen)
{
    if (name == NULL || value == NULL || name[0] == 0 || name[1] != 0)
        return FALSE;
    char d = SalCfgImpDetail::AsciiLower(name[0]);
    if (d < 'a' || d > 'z')
        return FALSE;
    int l = (int)strlen(value);
    if (l < 3 || l >= maxLen)
        return FALSE;
    return SalCfgImpDetail::AsciiLower(value[0]) == d && value[1] == ':' && value[2] == '\\';
}

//
// ****************************************************************************
// Values the import must never write (TC-owned or session state, research R15)
//

inline BOOL SalCfgImpIsForbiddenOption(const char* subkey, const char* name)
{
    if (subkey == NULL || name == NULL)
        return TRUE;
    static const char* const configForbidden[] = {
        "Theme Mode", "Panel Tabs", "Quick Search Filter",
        "Command Shell Preset", "Command Shell Program", "Command Shell Arguments",
        "Language", "Use Alternate Language for Plugins", "Alternate Language for Plugins", "Language Changed",
        "Plugins.ver Version (x64)", "Plugins.ver Version (x86)",
        "Enable Custom Icon Overlays", "Disabled Custom Icon Overlays",
        "Main window icon index", "Conversion Table", "Only One Instance",
        "Last Focused Page", "Configuration Height", "Viewers And Editors Expanded",
        "Packers And Unpackers Expanded", "Skill Level",
        "Top ToolBar", "Middle ToolBar", "Left ToolBar", "Right ToolBar",
        "Save Configuration On Exit", "Current Tip Index", "Show Translation Is Incomplete",
        "Right Panel Focused", "Command Line", "Command Line Focused",
        "Menu Index", "Menu Break", "Menu Width", "ToolBar Index", "ToolBar Break", "ToolBar Width",
        "PluginsBar Index", "PluginsBar Break", "PluginsBar Width", "User Menu Index", "User Menu Break",
        "User Menu Width", "User Menu Labels", "Hot Paths Index", "Hot Paths Break", "Hot Paths Width",
        "Drive Bar Index", "Drive Bar Break", "Drive Bar Width", "Grips Visible",
        "Show Top ToolBar", "Show Plugins Bar", "Show Middle ToolBar", "Show User Menu ToolBar",
        "Hot Paths Bar", "Show Drive Bar", "Show Drive Bar2", "Show Bottom ToolBar",
        "Always On Top", "Show Splash Screen", "Explorer Look",
        NULL};
    static const char* const viewerForbidden[] = {
        "Save Window Position", "Left", "Right", "Top", "Bottom", "Show", "Find Text", "HEX-mode", NULL};
    const char* const* list = NULL;
    if (SalCfgImpDetail::NameEqCI(subkey, "Configuration"))
        list = configForbidden;
    else if (SalCfgImpDetail::NameEqCI(subkey, "Viewer"))
        list = viewerForbidden;
    if (list == NULL)
        return FALSE;
    int i;
    for (i = 0; list[i] != NULL; i++)
    {
        if (SalCfgImpDetail::NameEqCI(list[i], name))
            return TRUE;
    }
    return FALSE;
}

//
// ****************************************************************************
// Plug-in DLL matching
//

namespace SalCfgImpDetail
{
    inline BOOL IsAbsolutePath(const char* p)
    {
        return p != NULL && ((p[0] != 0 && p[1] == ':') || (p[0] == '\\' && p[1] == '\\') ||
                             (p[0] == '/' && p[1] == '/'));
    }

    // the start of the last 'n' components of 'p' (separators '\' or '/')
    inline const char* LastComponents(const char* p, int n)
    {
        const char* e = p + strlen(p);
        const char* s = e;
        int found = 0;
        while (s > p)
        {
            if (s[-1] == '\\' || s[-1] == '/')
            {
                found++;
                if (found == n)
                    return s;
            }
            s--;
        }
        return p;
    }

    inline BOOL PathEqCISep(const char* a, const char* b)
    {
        while (*a != 0 && *b != 0)
        {
            char ca = *a == '/' ? '\\' : AsciiLower(*a);
            char cb = *b == '/' ? '\\' : AsciiLower(*b);
            if (ca != cb)
                return FALSE;
            a++;
            b++;
        }
        return *a == 0 && *b == 0;
    }
} // namespace SalCfgImpDetail

// the same plug-in: equal relative DLL paths ("ftp\ftp.spl"), or for an absolute source path its
// last two components equal to the last two of 'tcDll'
inline BOOL SalCfgImpSameDll(const char* srcDll, const char* tcDll)
{
    if (srcDll == NULL || tcDll == NULL || *srcDll == 0 || *tcDll == 0)
        return FALSE;
    const char* a = srcDll;
    const char* b = tcDll;
    if (SalCfgImpDetail::IsAbsolutePath(a) || SalCfgImpDetail::IsAbsolutePath(b))
    {
        a = SalCfgImpDetail::LastComponents(a, 2);
        b = SalCfgImpDetail::LastComponents(b, 2);
    }
    return SalCfgImpDetail::PathEqCISep(a, b);
}

//
// ****************************************************************************
// Parsers: snapshot -> records (each mirrors the program's own loader)
//

// ---- hot paths ("Hot Paths\0..30"; "0" was slot 10 when there were ten slots)

struct CSalCfgImpHotPath
{
    BOOL Used;     // a path is stored in the slot
    char* Name;    // custom name ("" = unnamed: the label follows the path, feature 047)
    char* Path;    // stored (escaped) form
    BOOL Visible;  // shown in the menus
    BOOL TooLong;  // stored name or path did not fit the program's limits (slot skipped)
};

#define SALCFGIMP_HOTPATHS 30

inline void SalCfgImpFreeHotPaths(CSalCfgImpHotPath* items, int count)
{
    int i;
    for (i = 0; i < count; i++)
    {
        free(items[i].Name);
        free(items[i].Path);
        items[i].Name = items[i].Path = NULL;
        items[i].Used = FALSE;
    }
}

// 'out' has SALCFGIMP_HOTPATHS zeroed entries; 'maxName'/'maxPath' are the program's buffer sizes;
// returns the number of used slots
inline int SalCfgImpParseHotPaths(const CSalCfgKey* hotPaths, DWORD srcVer, int maxName, int maxPath,
                                  CSalCfgImpHotPath* out)
{
    int used = 0;
    if (hotPaths == NULL)
        return 0;
    char* path = (char*)malloc(maxPath);
    char* text = (char*)malloc(maxPath);
    char* name = (char*)malloc(maxName);
    if (path == NULL || text == NULL || name == NULL)
    {
        free(path);
        free(text);
        free(name);
        return 0;
    }
    int i;
    for (i = 0; i <= SALCFGIMP_HOTPATHS; i++)
    {
        char keyName[8];
        _snprintf_s(keyName, _TRUNCATE, "%d", i);
        const CSalCfgKey* k = SalCfgKeyFindChild(hotPaths, keyName);
        if (k == NULL)
            continue;
        int index = (i == 0) ? 9 : i - 1;
        CSalCfgImpHotPath* item = &out[index];
        free(item->Name);
        free(item->Path);
        item->Name = item->Path = NULL;
        item->Used = FALSE;
        item->TooLong = FALSE;
        DWORD visible = TRUE;
        SalCfgGetDword(k, "Visible", &visible);
        item->Visible = visible != 0;

        const char* n = SalCfgGetString(k, "Name");
        const char* p = SalCfgGetString(k, "Path");
        name[0] = 0;
        if (n != NULL && !SalCfgImpDetail::Copy(name, maxName, n))
            item->TooLong = TRUE;
        // CleanName: trim spaces
        {
            char* s = name;
            while (*s == ' ')
                s++;
            char* e = s + strlen(s);
            while (e > s && e[-1] == ' ')
                e--;
            *e = 0;
            if (s != name)
                memmove(name, s, strlen(s) + 1);
        }
        path[0] = 0;
        if (p != NULL)
        {
            if (srcVer < 47)
            {
                if (!SalCfgImpDuplicateDollars(p, path, maxPath))
                    item->TooLong = TRUE;
            }
            else if (!SalCfgImpDetail::Copy(path, maxPath, p))
                item->TooLong = TRUE;
        }
        if (item->TooLong || path[0] == 0)
            continue;
        if (name[0] != 0 && SalCfgImpUnescapeDollars(path, text, maxPath) && strcmp(name, text) == 0)
            name[0] = 0; // feature 047: a name equal to the path text is the historical auto-fill
        item->Name = SalCfgImpDetail::Dup(name);
        item->Path = SalCfgImpDetail::Dup(path);
        if (item->Name == NULL || item->Path == NULL)
        {
            free(item->Name);
            free(item->Path);
            item->Name = item->Path = NULL;
            continue;
        }
        item->Used = TRUE;
    }
    for (i = 0; i < SALCFGIMP_HOTPATHS; i++)
    {
        if (out[i].Used)
            used++;
    }
    free(path);
    free(text);
    free(name);
    return used;
}

// ---- user menu ("User Menu\1..n", read until the first missing or invalid item)

#define SALCFGIMP_UM_ITEM 0         // umitItem
#define SALCFGIMP_UM_SUBMENUBEGIN 1 // umitSubmenuBegin
#define SALCFGIMP_UM_SUBMENUEND 2   // umitSubmenuEnd
#define SALCFGIMP_UM_SEPARATOR 3    // umitSeparator

struct CSalCfgImpMenuItem
{
    char* Name;
    char* Command;
    char* Arguments;
    char* InitDir;
    char* Icon;
    DWORD ThroughShell;
    DWORD CloseShell;
    DWORD UseWindow;
    DWORD ShowInToolbar;
    DWORD Type; // SALCFGIMP_UM_*
};

inline void SalCfgImpFreeMenu(CSalCfgImpMenuItem* items, int count)
{
    if (items == NULL)
        return;
    int i;
    for (i = 0; i < count; i++)
    {
        free(items[i].Name);
        free(items[i].Command);
        free(items[i].Arguments);
        free(items[i].InitDir);
        free(items[i].Icon);
    }
    free(items);
}

// '*out' gets an array (free with SalCfgImpFreeMenu); '*stopReason' (if not NULL): 0 = all read,
// 1 = stopped at an item missing a required value, 2 = stopped at a too long value
inline int SalCfgImpParseUserMenu(const CSalCfgKey* menu, int maxPath, int maxArgs, CSalCfgImpMenuItem** out,
                                  int* stopReason, int* skippedTooLong = NULL)
{
    *out = NULL;
    if (stopReason != NULL)
        *stopReason = 0;
    if (skippedTooLong != NULL)
        *skippedTooLong = 0;
    int skipDepth = 0; // > 0: inside a submenu whose beginning was skipped (too long)
    if (menu == NULL)
        return 0;
    int cap = menu->KeyCount + 1;
    CSalCfgImpMenuItem* items = (CSalCfgImpMenuItem*)calloc(cap, sizeof(CSalCfgImpMenuItem));
    if (items == NULL)
        return 0;
    int count = 0;
    int i;
    for (i = 1; count < cap; i++)
    {
        char keyName[16];
        _snprintf_s(keyName, _TRUNCATE, "%d", i);
        const CSalCfgKey* k = SalCfgKeyFindChild(menu, keyName);
        if (k == NULL)
            break;
        const char* name = SalCfgGetString(k, "Item Name");
        const char* command = SalCfgGetString(k, "Command");
        DWORD throughShell, closeShell;
        if (name == NULL || command == NULL || !SalCfgGetDword(k, "Execute Through Shell", &throughShell) ||
            !SalCfgGetDword(k, "Close Shell Window", &closeShell))
        {
            if (stopReason != NULL)
                *stopReason = 1;
            break;
        }
        const char* arguments = SalCfgGetString(k, "Arguments");
        const char* initDir = SalCfgGetString(k, "Initial Directory");
        const char* icon = SalCfgGetString(k, "Icon");
        if (arguments == NULL)
            arguments = "";
        if (initDir == NULL)
            initDir = "$(Drive)$(Path)";
        if (icon == NULL)
            icon = "";
        DWORD useWindow = TRUE, separator = FALSE, type, showInToolbar = TRUE;
        SalCfgGetDword(k, "Open Shell Window", &useWindow);
        SalCfgGetDword(k, "Separator", &separator);
        if (!SalCfgGetDword(k, "Type", &type))
            type = separator ? SALCFGIMP_UM_SEPARATOR : SALCFGIMP_UM_ITEM;
        if (type > SALCFGIMP_UM_SEPARATOR)
            type = SALCFGIMP_UM_ITEM;
        SalCfgGetDword(k, "Show In Toolbar", &showInToolbar);
        if (skipDepth > 0) // the rest of a skipped submenu (its structure stays balanced)
        {
            if (type == SALCFGIMP_UM_SUBMENUBEGIN)
                skipDepth++;
            else if (type == SALCFGIMP_UM_SUBMENUEND)
                skipDepth--;
            continue;
        }
        if (type == SALCFGIMP_UM_SUBMENUEND) // its texts are not used: the structure stays balanced
            name = command = arguments = icon = "", initDir = "";
        if ((int)strlen(name) >= maxPath || (int)strlen(command) >= maxPath || (int)strlen(arguments) >= maxArgs ||
            (int)strlen(initDir) >= maxPath || (int)strlen(icon) >= maxPath)
        {
            // never cut: this entry (a submenu with all its entries) is left out, the rest is read
            if (skippedTooLong != NULL)
                (*skippedTooLong)++;
            if (type == SALCFGIMP_UM_SUBMENUBEGIN)
                skipDepth = 1;
            continue;
        }
        CSalCfgImpMenuItem* it = &items[count];
        it->Name = SalCfgImpDetail::Dup(name);
        it->Command = SalCfgImpDetail::Dup(command);
        it->Arguments = SalCfgImpDetail::Dup(arguments);
        it->InitDir = SalCfgImpDetail::Dup(initDir);
        it->Icon = SalCfgImpDetail::Dup(icon);
        it->ThroughShell = throughShell;
        it->CloseShell = closeShell;
        it->UseWindow = useWindow;
        it->ShowInToolbar = showInToolbar;
        it->Type = type;
        count++;
        if (it->Name == NULL || it->Command == NULL || it->Arguments == NULL || it->InitDir == NULL || it->Icon == NULL)
            break; // low memory: the item stays (freed by the caller) but reading stops
    }
    *out = items;
    return count;
}

// the identity of one entry (separators never equal anything: they are layout, not content)
inline BOOL SalCfgImpMenuItemEqual(const CSalCfgImpMenuItem* a, const CSalCfgImpMenuItem* b)
{
    if (a->Type != b->Type)
        return FALSE;
    if (a->Type == SALCFGIMP_UM_SEPARATOR)
        return FALSE;
    if (a->Type == SALCFGIMP_UM_SUBMENUEND)
        return TRUE;
    return strcmp(a->Name, b->Name) == 0 && strcmp(a->Command, b->Command) == 0 &&
           strcmp(a->Arguments, b->Arguments) == 0 && strcmp(a->InitDir, b->InitDir) == 0;
}

// the end (exclusive) of the top-level block starting at 'start': one entry, or a submenu
// begin with everything up to and including its matching end (an unmatched begin runs to the end)
inline int SalCfgImpMenuBlockEnd(const CSalCfgImpMenuItem* items, int count, int start)
{
    if (start >= count)
        return count;
    if (items[start].Type != SALCFGIMP_UM_SUBMENUBEGIN)
        return start + 1;
    int depth = 0;
    int i;
    for (i = start; i < count; i++)
    {
        if (items[i].Type == SALCFGIMP_UM_SUBMENUBEGIN)
            depth++;
        else if (items[i].Type == SALCFGIMP_UM_SUBMENUEND)
        {
            depth--;
            if (depth == 0)
                return i + 1;
        }
    }
    return count;
}

inline BOOL SalCfgImpMenuBlockEqual(const CSalCfgImpMenuItem* a, int aStart, int aEnd,
                                    const CSalCfgImpMenuItem* b, int bStart, int bEnd)
{
    if (aEnd - aStart != bEnd - bStart)
        return FALSE;
    int i;
    for (i = 0; i < aEnd - aStart; i++)
    {
        const CSalCfgImpMenuItem* x = &a[aStart + i];
        const CSalCfgImpMenuItem* y = &b[bStart + i];
        if (x->Type == SALCFGIMP_UM_SEPARATOR && y->Type == SALCFGIMP_UM_SEPARATOR)
            continue; // inside a block separators are part of its content
        if (!SalCfgImpMenuItemEqual(x, y))
            return FALSE;
    }
    return TRUE;
}

#define SALCFGIMP_UMD_APPEND 0  // appended
#define SALCFGIMP_UMD_PRESENT 1 // the same top-level block exists already
#define SALCFGIMP_UMD_DROPSEP 2 // a top-level separator not needed between appended blocks
#define SALCFGIMP_UMD_INBLOCK 3 // part of the block decided by its first entry

// Add mode of the user menu: decides for every source entry (decision[srcCount]); top-level
// separators are kept only between two appended blocks, and one in front of the first appended
// block when the current menu is not empty
inline void SalCfgImpPlanUserMenuAdd(const CSalCfgImpMenuItem* cur, int curCount, const CSalCfgImpMenuItem* src,
                                     int srcCount, int* decision)
{
    int i = 0;
    int pendingSep = -1;     // index of a top-level separator waiting for the next appended block
    BOOL appended = FALSE;   // something was appended already
    while (i < srcCount)
    {
        int end = SalCfgImpMenuBlockEnd(src, srcCount, i);
        int k;
        for (k = i + 1; k < end; k++)
            decision[k] = SALCFGIMP_UMD_INBLOCK;
        if (src[i].Type == SALCFGIMP_UM_SEPARATOR || src[i].Type == SALCFGIMP_UM_SUBMENUEND) // stray end = layout
        {
            decision[i] = SALCFGIMP_UMD_DROPSEP;
            if (src[i].Type == SALCFGIMP_UM_SEPARATOR && appended && pendingSep < 0)
                pendingSep = i;
            i = end;
            continue;
        }
        BOOL present = FALSE;
        int c = 0;
        while (c < curCount)
        {
            int cEnd = SalCfgImpMenuBlockEnd(cur, curCount, c);
            if (SalCfgImpMenuBlockEqual(cur, c, cEnd, src, i, end))
            {
                present = TRUE;
                break;
            }
            c = cEnd;
        }
        if (present)
            decision[i] = SALCFGIMP_UMD_PRESENT;
        else
        {
            decision[i] = SALCFGIMP_UMD_APPEND;
            if (pendingSep >= 0)
                decision[pendingSep] = SALCFGIMP_UMD_APPEND;
            pendingSep = -1;
            appended = TRUE;
        }
        i = end;
    }
}

// ---- viewers, alternative viewers, editors ("<key>\1..n", read until the first invalid row)

struct CSalCfgImpViewer
{
    char* Masks;
    char* Command;
    char* Arguments;
    char* InitDir;
    int Type; // viewers: 0 external, 1 internal, < 0 plug-in -(index+1); editors: 0
};

inline void SalCfgImpFreeViewers(CSalCfgImpViewer* items, int count)
{
    if (items == NULL)
        return;
    int i;
    for (i = 0; i < count; i++)
    {
        free(items[i].Masks);
        free(items[i].Command);
        free(items[i].Arguments);
        free(items[i].InitDir);
    }
    free(items);
}

#define SALCFGIMP_VSTOP_NONE 0
#define SALCFGIMP_VSTOP_INVALID 1 // a row without masks/type: the program stops reading there too
#define SALCFGIMP_VSTOP_PIPE 2    // a row with '|' in its masks: the program stops reading there too
#define SALCFGIMP_VSTOP_TOOLONG 3 // a value longer than the program's buffer

inline int SalCfgImpParseViewers(const CSalCfgKey* key, BOOL editors, DWORD srcVer, int maxPath,
                                 CSalCfgImpViewer** out, int* stopReason, int* skippedTooLong = NULL)
{
    *out = NULL;
    if (stopReason != NULL)
        *stopReason = SALCFGIMP_VSTOP_NONE;
    if (skippedTooLong != NULL)
        *skippedTooLong = 0;
    if (key == NULL)
        return 0;
    int cap = key->KeyCount + 1;
    CSalCfgImpViewer* items = (CSalCfgImpViewer*)calloc(cap, sizeof(CSalCfgImpViewer));
    if (items == NULL)
        return 0;
    int count = 0;
    int i;
    for (i = 1; count < cap; i++)
    {
        char keyName[16];
        _snprintf_s(keyName, _TRUNCATE, "%d", i);
        const CSalCfgKey* k = SalCfgKeyFindChild(key, keyName);
        if (k == NULL)
            break;
        const char* masks = SalCfgGetString(k, "Masks");
        DWORD type = 0;
        if (masks == NULL || (!editors && !SalCfgGetDword(k, "Type", &type)))
        {
            if (stopReason != NULL)
                *stopReason = SALCFGIMP_VSTOP_INVALID;
            break;
        }
        if (!editors && strchr(masks, '|') != NULL)
        {
            if (stopReason != NULL)
                *stopReason = SALCFGIMP_VSTOP_PIPE;
            break;
        }
        const char* command = SalCfgGetString(k, "Command");
        const char* arguments = SalCfgGetString(k, "Arguments");
        const char* initDir = SalCfgGetString(k, "Initial Directory");
        if (command == NULL)
            command = "";
        if (arguments == NULL)
            arguments = "";
        if (initDir == NULL)
            initDir = "";
        if ((int)strlen(masks) >= maxPath || (int)strlen(command) >= maxPath || (int)strlen(arguments) >= maxPath ||
            (int)strlen(initDir) >= maxPath)
        {
            // never cut: this row is left out, the rest is read
            if (skippedTooLong != NULL)
                (*skippedTooLong)++;
            continue;
        }
        CSalCfgImpViewer* it = &items[count];
        it->Masks = (char*)malloc(strlen(masks) + 1);
        if (it->Masks != NULL)
        {
            if (srcVer < 44)
                SalCfgImpLowerAscii(masks, it->Masks, (int)strlen(masks) + 1);
            else
                strcpy(it->Masks, masks);
        }
        it->Command = SalCfgImpDetail::Dup(command);
        it->Arguments = SalCfgImpDetail::Dup(arguments);
        it->InitDir = SalCfgImpDetail::Dup(initDir);
        it->Type = editors ? 0 : (int)type;
        count++;
        if (it->Masks == NULL || it->Command == NULL || it->Arguments == NULL || it->InitDir == NULL)
            break;
    }
    *out = items;
    return count;
}

// ---- plug-in registrations ("Plugins\1..n"): DLL, configuration key, user-assigned hot keys

#define SALCFGIMP_HOTKEY_DIRTY 0x00010000 // HOTKEY_DIRTY of plugins.h: assigned by the user
#define SALCFGIMP_HOTKEY_MASK 0x0000FFFF

struct CSalCfgImpPluginKey
{
    DWORD ID;     // menu item id within the plug-in
    DWORD HotKey; // as stored (low word = key + modifiers, HOTKEY_DIRTY = user-assigned)
    char* Name;   // the menu item's name as stored (for reports)
};

struct CSalCfgImpPlugin
{
    int Index;       // 0-based position in the source's plug-in list (viewer types refer to it)
    char* DLL;       // as stored ("ftp\ftp.spl" or an absolute path)
    char* ConfigKey; // "Configuration Key" ("" when none)
    char* Name;      // display name as stored
    CSalCfgImpPluginKey* Keys;
    int KeyCount;
};

inline void SalCfgImpFreePlugins(CSalCfgImpPlugin* items, int count)
{
    if (items == NULL)
        return;
    int i;
    for (i = 0; i < count; i++)
    {
        free(items[i].DLL);
        free(items[i].ConfigKey);
        free(items[i].Name);
        int j;
        for (j = 0; j < items[i].KeyCount; j++)
            free(items[i].Keys[j].Name);
        free(items[i].Keys);
    }
    free(items);
}

// reads "Plugins\1.." until the first missing key; entries without a DLL keep their position
// (DLL "") so the indexes stay those of the source program
inline int SalCfgImpParsePlugins(const CSalCfgKey* plugins, CSalCfgImpPlugin** out)
{
    *out = NULL;
    if (plugins == NULL)
        return 0;
    int cap = plugins->KeyCount + 1;
    CSalCfgImpPlugin* items = (CSalCfgImpPlugin*)calloc(cap, sizeof(CSalCfgImpPlugin));
    if (items == NULL)
        return 0;
    int count = 0;
    int i;
    for (i = 1; count < cap; i++)
    {
        char keyName[16];
        _snprintf_s(keyName, _TRUNCATE, "%d", i);
        const CSalCfgKey* k = SalCfgKeyFindChild(plugins, keyName);
        if (k == NULL)
            break;
        CSalCfgImpPlugin* p = &items[count];
        p->Index = count;
        const char* dll = SalCfgGetString(k, "DLL");
        const char* cfg = SalCfgGetString(k, "Configuration Key");
        const char* name = SalCfgGetString(k, "Name");
        p->DLL = SalCfgImpDetail::Dup(dll != NULL ? dll : "");
        p->ConfigKey = SalCfgImpDetail::Dup(cfg != NULL ? cfg : "");
        p->Name = SalCfgImpDetail::Dup(name != NULL ? name : "");
        count++;
        if (p->DLL == NULL || p->ConfigKey == NULL || p->Name == NULL)
            break;
        const CSalCfgKey* menu = SalCfgKeyFindChild(k, "Menu");
        if (menu != NULL && menu->KeyCount > 0)
        {
            p->Keys = (CSalCfgImpPluginKey*)calloc(menu->KeyCount, sizeof(CSalCfgImpPluginKey));
            if (p->Keys != NULL)
            {
                int m;
                for (m = 1; p->KeyCount < menu->KeyCount; m++)
                {
                    char itemName[16];
                    _snprintf_s(itemName, _TRUNCATE, "%d", m);
                    const CSalCfgKey* mk = SalCfgKeyFindChild(menu, itemName);
                    if (mk == NULL)
                        break;
                    DWORD id, hotKey;
                    if (!SalCfgGetDword(mk, "ID", &id) || !SalCfgGetDword(mk, "HotKey", &hotKey) ||
                        (hotKey & SALCFGIMP_HOTKEY_MASK) == 0)
                        continue;
                    const char* itemText = SalCfgGetString(mk, "Name");
                    CSalCfgImpPluginKey* pk = &p->Keys[p->KeyCount];
                    pk->Name = SalCfgImpDetail::Dup(itemText != NULL ? itemText : "");
                    if (pk->Name == NULL)
                        break;
                    pk->ID = id;
                    pk->HotKey = hotKey;
                    p->KeyCount++;
                }
            }
        }
    }
    *out = items;
    return count;
}

// ---- histories ("<name>\1..cap"): pointers into the snapshot, invalid entries skipped

namespace SalCfgImpDetail
{
    inline BOOL IsValidUtf8(const char* s)
    {
        const unsigned char* p = (const unsigned char*)s;
        while (*p != 0)
        {
            if (*p < 0x80)
            {
                p++;
                continue;
            }
            int n;
            if ((*p & 0xE0) == 0xC0)
                n = 1;
            else if ((*p & 0xF0) == 0xE0)
                n = 2;
            else if ((*p & 0xF8) == 0xF0)
                n = 3;
            else
                return FALSE;
            if (*p == 0xC0 || *p == 0xC1 || *p > 0xF4)
                return FALSE;
            p++;
            while (n-- > 0)
            {
                if ((*p & 0xC0) != 0x80)
                    return FALSE;
                p++;
            }
        }
        return TRUE;
    }
} // namespace SalCfgImpDetail

inline int SalCfgImpParseHistory(const CSalCfgKey* history, const char** out, int cap)
{
    int n = 0;
    if (history == NULL)
        return 0;
    int i;
    for (i = 0; i < cap; i++)
    {
        char name[16];
        _snprintf_s(name, _TRUNCATE, "%d", i + 1);
        const char* s = SalCfgGetString(history, name);
        if (s == NULL)
            continue;
        if (s[0] == 0 || !SalCfgImpDetail::IsValidUtf8(s))
            continue;
        out[n++] = s;
    }
    return n;
}
