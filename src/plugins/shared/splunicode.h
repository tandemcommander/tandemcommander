// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// splunicode.h
//
// Header-only UTF-8/UTF-16 helpers for plugins built against plugin
// interface 104 (feature 004-long-paths-unicode). Since interface 104
// every char* file name and path crossing the Salamander plugin
// interface is UTF-8; see doc/plugin-vnext-migration.md.
//
// Use these helpers to call W file APIs from a plugin:
//
//   WCHAR* w = SplU8ToWExtAlloc(u8path);          // \\?\-prefixed, for file APIs
//   HANDLE h = CreateFileW(w, ...);
//   free(w);
//
// All allocating helpers return NULL on failure; free() the results.
//
// Since feature 089 the helpers are WTF-8 like the core's own converters: a
// file name with an unpaired UTF-16 surrogate (legal on NTFS) converts in both
// directions instead of failing. For valid Unicode nothing changed, and bytes
// that are neither UTF-8 nor such a surrogate sequence still fail - a plugin
// may keep using that failure to recognise legacy (code page) text.
//

#include <windows.h>
#include <stdlib.h>
#include <string.h>

// ---------------------------------------------------------------------------
// WTF-8 (feature 089). The program's names are WTF-8 since feature 066: valid
// Unicode is plain UTF-8, and an UNPAIRED UTF-16 surrogate - legal in an NTFS
// file name - is carried as the 3-byte sequence ED A0 80 .. ED BF BF, which
// strict UTF-8 forbids. The helpers below try the strict Windows conversion
// first (so everything that worked before is byte-identical) and fall back to
// these two routines only when it refuses. Every other malformed input still
// fails. The algorithm is the core's (src/common/salunicode.cpp); see
// specs/066-fix-surrogate-filenames/contracts/name-encoding-wtf8.md.
namespace SplUnicodeDetail
{
// encodes the null-terminated 'w' (terminator included) as WTF-8; returns the
// byte count, or 0 when 'buf' is too small ('buf' NULL just measures)
inline int WToWtf8(const WCHAR* w, char* buf, int bufSize)
{
    int out = 0;
    for (int i = 0;; i++)
    {
        DWORD cp = w[i];
        if (cp >= 0xD800 && cp <= 0xDBFF && w[i + 1] >= 0xDC00 && w[i + 1] <= 0xDFFF)
        { // a valid pair -> one supplementary code point (identical to UTF-8)
            cp = 0x10000 + ((cp - 0xD800) << 10) + (w[i + 1] - 0xDC00);
            i++;
        }
        int seq = cp < 0x80 ? 1 : cp < 0x800 ? 2
                              : cp < 0x10000 ? 3 // BMP incl. a LONE surrogate (the WTF-8 extension)
                                             : 4;
        if (buf != NULL)
        {
            if (out + seq > bufSize)
                return 0;
            switch (seq)
            {
            case 1:
                buf[out] = (char)cp;
                break;
            case 2:
                buf[out] = (char)(0xC0 | (cp >> 6));
                buf[out + 1] = (char)(0x80 | (cp & 0x3F));
                break;
            case 3:
                buf[out] = (char)(0xE0 | (cp >> 12));
                buf[out + 1] = (char)(0x80 | ((cp >> 6) & 0x3F));
                buf[out + 2] = (char)(0x80 | (cp & 0x3F));
                break;
            case 4:
                buf[out] = (char)(0xF0 | (cp >> 18));
                buf[out + 1] = (char)(0x80 | ((cp >> 12) & 0x3F));
                buf[out + 2] = (char)(0x80 | ((cp >> 6) & 0x3F));
                buf[out + 3] = (char)(0x80 | (cp & 0x3F));
                break;
            }
        }
        out += seq;
        if (cp == 0)
            return out;
    }
}

// decodes the null-terminated WTF-8 'u8' (terminator included): strict UTF-8
// whose 3-byte sequences may additionally decode to a lone surrogate. Returns
// the WCHAR count, or 0 on any other malformed input or when 'buf' is too
// small ('buf' NULL just measures).
inline int Wtf8ToW(const char* u8, WCHAR* buf, int bufSize)
{
    const unsigned char* s = (const unsigned char*)u8;
    int out = 0;
    for (;;)
    {
        DWORD cp;
        int seq;
        unsigned char b = *s;
        if (b < 0x80)
        {
            cp = b;
            seq = 1;
        }
        else if (b >= 0xC2 && b <= 0xDF)
        {
            cp = b & 0x1F;
            seq = 2;
        }
        else if (b >= 0xE0 && b <= 0xEF)
        {
            cp = b & 0x0F;
            seq = 3;
        }
        else if (b >= 0xF0 && b <= 0xF4)
        {
            cp = b & 0x07;
            seq = 4;
        }
        else
            return 0; // stray continuation byte, overlong C0/C1, or F5..FF
        for (int k = 1; k < seq; k++)
        {
            unsigned char c = s[k];
            if (c < 0x80 || c > 0xBF)
                return 0; // also a sequence cut by the terminator
            cp = (cp << 6) | (c & 0x3F);
        }
        // minimality and range as in strict UTF-8; the ONLY extension is that a
        // 3-byte sequence may decode to a surrogate
        if ((seq == 2 && cp < 0x80) || (seq == 3 && cp < 0x800) ||
            (seq == 4 && (cp < 0x10000 || cp > 0x10FFFF)))
            return 0;
        if (cp >= 0x10000)
        {
            if (buf != NULL)
            {
                if (out + 2 > bufSize)
                    return 0;
                buf[out] = (WCHAR)(0xD800 + ((cp - 0x10000) >> 10));
                buf[out + 1] = (WCHAR)(0xDC00 + ((cp - 0x10000) & 0x3FF));
            }
            out += 2;
        }
        else
        {
            if (buf != NULL)
            {
                if (out + 1 > bufSize)
                    return 0;
                buf[out] = (WCHAR)cp;
            }
            out++;
        }
        if (cp == 0)
            return out;
        s += seq;
    }
}
} // namespace SplUnicodeDetail

// UTF-8 (WTF-8) -> UTF-16; fails on any other malformed sequence; free() the result
inline WCHAR* SplU8ToWAlloc(const char* u8)
{
    if (u8 == NULL)
        return NULL;
    BOOL strict = TRUE;
    int len = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u8, -1, NULL, 0);
    if (len <= 0)
    {
        strict = FALSE;
        len = SplUnicodeDetail::Wtf8ToW(u8, NULL, 0);
        if (len <= 0)
            return NULL;
    }
    WCHAR* w = (WCHAR*)malloc(len * sizeof(WCHAR));
    if (w != NULL)
    {
        if (strict)
            MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u8, -1, w, len);
        else
            SplUnicodeDetail::Wtf8ToW(u8, w, len);
    }
    return w;
}

// UTF-16 -> UTF-8 (WTF-8: total, an unpaired surrogate is encoded as its
// 3-byte sequence); free() the result
inline char* SplWToU8Alloc(const WCHAR* w)
{
    if (w == NULL)
        return NULL;
    BOOL strict = TRUE;
    int len = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, w, -1, NULL, 0, NULL, NULL);
    if (len <= 0)
    {
        strict = FALSE;
        len = SplUnicodeDetail::WToWtf8(w, NULL, 0);
        if (len <= 0)
            return NULL;
    }
    char* u8 = (char*)malloc(len);
    if (u8 != NULL)
    {
        if (strict)
            WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, w, -1, u8, len, NULL, NULL);
        else
            SplUnicodeDetail::WToWtf8(w, u8, len);
    }
    return u8;
}

// UTF-16 -> UTF-8 (WTF-8) into a caller buffer; returns bytes written incl. the
// terminator, 0 on failure (buffer too small)
inline int SplWToU8(const WCHAR* w, char* buf, int bufSize)
{
    if (w == NULL || buf == NULL || bufSize <= 0)
        return 0;
    int res = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, w, -1, buf, bufSize, NULL, NULL);
    if (res <= 0)
        res = SplUnicodeDetail::WToWtf8(w, buf, bufSize); // an unpaired surrogate (0 when the buffer is too small)
    if (res <= 0)
    {
        buf[0] = 0;
        res = 0;
    }
    return res;
}

// UTF-8 (WTF-8) -> UTF-16 into a caller buffer; returns WCHARs written incl. the
// terminator, 0 on failure (malformed input or buffer too small)
inline int SplU8ToW(const char* u8, WCHAR* buf, int bufSizeInWchars)
{
    if (u8 == NULL || buf == NULL || bufSizeInWchars <= 0)
        return 0;
    int res = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u8, -1, buf, bufSizeInWchars);
    if (res <= 0)
        res = SplUnicodeDetail::Wtf8ToW(u8, buf, bufSizeInWchars); // a surrogate sequence (0 when malformed or too small)
    if (res <= 0)
    {
        buf[0] = 0;
        res = 0;
    }
    return res;
}

// TRUE when the buffer contains only ASCII (fast-path predicate)
inline BOOL SplIsASCII(const char* s)
{
    if (s == NULL)
        return TRUE;
    for (; *s != 0; s++)
        if ((unsigned char)*s >= 0x80)
            return FALSE;
    return TRUE;
}

// UTF-8 display-form path -> heap UTF-16 extended-length path for W file
// APIs: "C:\..." -> "\\?\C:\...", "\\server\share\..." -> "\\?\UNC\...";
// already-prefixed paths pass through; relative paths are returned
// unprefixed (extended-length form requires absolute paths).
// free() the result; NULL on conversion failure.
inline WCHAR* SplU8ToWExtAlloc(const char* u8path)
{
    WCHAR* w = SplU8ToWAlloc(u8path);
    if (w == NULL)
        return NULL;
    if (wcsncmp(w, L"\\\\?\\", 4) == 0)
        return w; // already extended
    BOOL isDrive = ((w[0] >= L'A' && w[0] <= L'Z') || (w[0] >= L'a' && w[0] <= L'z')) &&
                   w[1] == L':' && w[2] == L'\\';
    BOOL isUNC = w[0] == L'\\' && w[1] == L'\\';
    if (!isDrive && !isUNC)
        return w; // relative path: cannot be \\?\-prefixed, return as-is
    const WCHAR* prefix = isDrive ? L"\\\\?\\" : L"\\\\?\\UNC\\";
    size_t skip = isDrive ? 0 : 2;
    size_t prefixLen = wcslen(prefix);
    size_t len = wcslen(w);
    WCHAR* ext = (WCHAR*)malloc((prefixLen + len - skip + 1) * sizeof(WCHAR));
    if (ext != NULL)
    {
        memcpy(ext, prefix, prefixLen * sizeof(WCHAR));
        memcpy(ext + prefixLen, w + skip, (len - skip + 1) * sizeof(WCHAR));
    }
    free(w);
    return ext;
}
