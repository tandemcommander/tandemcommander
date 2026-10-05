// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcsumlist.h
//
// Reading a checksum list (.sfv .md5 .sha1 .sha256 .sha512) in the Checksum
// plug-in (feature 117). Until this feature the plug-in took the list's bytes
// as UTF-8, so a list whose names are in the system code page (Open Salamander,
// Total Commander for names that fit the code page, PowerShell Set-Content,
// most older Windows tools) reported every accented name "missing", a UTF-8
// list with a byte order mark was "not a checksum file", a UTF-16 list
// (PowerShell 5.1 '>' / Out-File) too, and every "./name" or "dir/../name" line
// was "missing" (the extended-length path keeps '.' and '..' literally).
//
// The rules (contract: specs/117-checksum-lists/research.md, section D):
//   1. The encoding is decided ONCE for the whole file, never per line:
//      a byte order mark (UTF-8, UTF-16 LE, UTF-16 BE) decides; else NUL bytes
//      on one parity mean UTF-16 without a mark (no text list holds NUL);
//      else a file that is WTF-8 as a whole is UTF-8; else it is the code page
//      given (the plug-in passes CP_ACP). OEM is never guessed - no signal
//      tells an OEM list from a code-page one.
//   2. The text is converted EXACTLY: no best fit, no look-alike. A byte or
//      unit that cannot be converted becomes SAL_CSL_BADCHAR (0xFF - a byte
//      that never occurs in UTF-8 and is not white space, so the line keeps its
//      shape), and a name holding it is reported, never looked up.
//   3. A name is looked up as the file system's own rule decides "the same
//      file" (feature 092): the path is passed to it; only '.' and '..'
//      components and empty ones are resolved here (lexically, never above the
//      root), because the plug-in's extended-length paths keep them literally.
//      Trailing dots and spaces are NOT stripped (the 102 lesson: that is
//      another file). Wildcard characters and ':' (a stream, another drive's
//      folder) make a name unusable - the directory look-up would match
//      another file. An absolute name outside the list's own drive or share
//      is never looked up (a UNC look-up connects to the server named and
//      sends the user's credentials).
//   4. NUL bytes: trailing ones and those at a line's start or end are
//      ignored (padding, written terminators); one inside a line becomes
//      SAL_CSL_BADCHAR - the line is never cut there.
//   Peak memory of SalCslDecode: the output up to 3x the input (a code-page
//   file), plus the UTF-16 intermediate up to 2x - with the caller's raw
//   buffer about 6x the list file's size.
//
// Header-only and pure (no globals): the plug-in cannot be linked into
// saltests, these rules can.
//
//*****************************************************************************

#include <windows.h>
#include <stdlib.h>
#include <string.h>

// stands for a byte / unit of the list that could not be converted (never valid UTF-8)
#define SAL_CSL_BADCHAR 0xFF

enum SalCslEncoding
{
    SAL_CSL_UTF8,        // no byte order mark, the whole file is UTF-8 (WTF-8)
    SAL_CSL_UTF8_BOM,    // EF BB BF
    SAL_CSL_UTF16LE_BOM, // FF FE
    SAL_CSL_UTF16BE_BOM, // FE FF
    SAL_CSL_UTF16LE,     // no mark, NUL bytes mostly at odd offsets
    SAL_CSL_UTF16BE,     // no mark, NUL bytes mostly at even offsets
    SAL_CSL_CODEPAGE     // none of the above: the code page given (CP_ACP in the plug-in)
};

namespace SalCslDetail
{
    // length of the WTF-8 sequence at 's' ('n' bytes available): strict UTF-8 whose
    // 3-byte sequences may also encode a lone surrogate (feature 066); 0 = invalid
    inline int Wtf8SeqLen(const unsigned char* s, size_t n)
    {
        unsigned char b = s[0];
        if (b < 0x80)
            return 1;
        int seq;
        DWORD cp;
        if (b >= 0xC2 && b <= 0xDF)
        {
            seq = 2;
            cp = b & 0x1F;
        }
        else if (b >= 0xE0 && b <= 0xEF)
        {
            seq = 3;
            cp = b & 0x0F;
        }
        else if (b >= 0xF0 && b <= 0xF4)
        {
            seq = 4;
            cp = b & 0x07;
        }
        else
            return 0;
        if ((size_t)seq > n)
            return 0;
        for (int k = 1; k < seq; k++)
        {
            if (s[k] < 0x80 || s[k] > 0xBF)
                return 0;
            cp = (cp << 6) | (s[k] & 0x3F);
        }
        if ((seq == 3 && cp < 0x800) || (seq == 4 && (cp < 0x10000 || cp > 0x10FFFF)))
            return 0;
        return seq;
    }

    // the output text under construction; drops U+FEFF at the start of a line (a
    // byte order mark left inside by concatenating two lists)
    struct COut
    {
        char* Buf;
        size_t Len;
        bool LineStart;
        size_t Bad;

        void Byte(unsigned char c)
        {
            Buf[Len++] = (char)c;
            LineStart = (c == '\n' || c == '\r');
        }
        void BadChar()
        {
            unsigned char bad = SAL_CSL_BADCHAR;
            Buf[Len++] = (char)bad;
            LineStart = false;
            Bad++;
        }
        // one code point (a lone surrogate is written as its WTF-8 sequence)
        void CodePoint(DWORD cp)
        {
            if (cp == 0)
            {
                BadChar(); // a NUL inside the text would end it
                return;
            }
            if (cp == 0xFEFF && LineStart)
                return;
            if (cp < 0x80)
                Byte((unsigned char)cp);
            else
            {
                if (cp < 0x800)
                {
                    Buf[Len++] = (char)(0xC0 | (cp >> 6));
                }
                else if (cp < 0x10000)
                {
                    Buf[Len++] = (char)(0xE0 | (cp >> 12));
                    Buf[Len++] = (char)(0x80 | ((cp >> 6) & 0x3F));
                }
                else
                {
                    Buf[Len++] = (char)(0xF0 | (cp >> 18));
                    Buf[Len++] = (char)(0x80 | ((cp >> 12) & 0x3F));
                    Buf[Len++] = (char)(0x80 | ((cp >> 6) & 0x3F));
                }
                Buf[Len++] = (char)(0x80 | (cp & 0x3F));
                LineStart = false;
            }
        }
        // a run of NULs ('count' of them; 'atLineEnd' = a line end or the end of the text follows):
        // nothing at the start or the end of a line (padding, a written terminator); inside a
        // line one SAL_CSL_BADCHAR each - the line is NOT cut there, a cut name could be another
        // file's ("voil<NUL>a.txt" must not become "voil")
        void Nuls(size_t count, bool atLineEnd)
        {
            if (LineStart || atLineEnd)
                return;
            for (size_t k = 0; k < count; k++)
                BadChar();
        }
        // UTF-16 units: a valid pair is one code point, an unpaired surrogate stays itself (WTF-8)
        void Units(const WCHAR* w, size_t n)
        {
            for (size_t i = 0; i < n; i++)
            {
                if (w[i] == 0)
                {
                    size_t j = i;
                    while (j < n && w[j] == 0)
                        j++;
                    Nuls(j - i, j == n || w[j] == '\r' || w[j] == '\n');
                    i = j - 1;
                    continue;
                }
                DWORD cp = w[i];
                if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < n && w[i + 1] >= 0xDC00 && w[i + 1] <= 0xDFFF)
                {
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (w[i + 1] - 0xDC00);
                    i++;
                }
                CodePoint(cp);
            }
        }
    };
} // namespace SalCslDetail

// TRUE when the whole buffer is WTF-8 (an empty buffer is)
inline BOOL SalCslIsWtf8(const unsigned char* d, size_t n)
{
    size_t i = 0;
    while (i < n)
    {
        int s = SalCslDetail::Wtf8SeqLen(d + i, n - i);
        if (s == 0)
            return FALSE;
        i += s;
    }
    return TRUE;
}

// rule 1: the encoding of the whole list file
inline SalCslEncoding SalCslDetect(const unsigned char* d, size_t n)
{
    if (n >= 3 && d[0] == 0xEF && d[1] == 0xBB && d[2] == 0xBF)
        return SAL_CSL_UTF8_BOM;
    if (n >= 2 && d[0] == 0xFF && d[1] == 0xFE)
        return SAL_CSL_UTF16LE_BOM;
    if (n >= 2 && d[0] == 0xFE && d[1] == 0xFF)
        return SAL_CSL_UTF16BE_BOM;
    // NUL bytes at the end (a zero-padded file, a C string written with its terminator) are
    // not text and do not decide anything
    size_t m = n;
    while (m > 0 && d[m - 1] == 0)
        m--;
    // UTF-16 without a mark: a list is mostly ASCII (the hexadecimal checksums), so the high
    // bytes of its units - NUL - sit on one parity: at least 1 NUL in 16 bytes and at most 1 in
    // 8 of them on the other parity; stray NULs in a byte text do not qualify
    size_t nulEven = 0, nulOdd = 0;
    for (size_t i = 0; i < m; i++)
    {
        if (d[i] == 0)
        {
            if (i & 1)
                nulOdd++;
            else
                nulEven++;
        }
    }
    if (nulOdd > 0 && nulEven * 8 <= nulOdd && nulOdd * 16 >= m)
        return SAL_CSL_UTF16LE;
    if (nulEven > 0 && nulOdd * 8 <= nulEven && nulEven * 16 >= m)
        return SAL_CSL_UTF16BE;
    if (SalCslIsWtf8(d, m)) // a stray NUL byte is WTF-8 too (see SalCslDecode)
        return SAL_CSL_UTF8;
    return SAL_CSL_CODEPAGE;
}

// rules 1 + 2: the list file's bytes as one null-terminated WTF-8 text (malloc'd, free()
// it; NULL only when out of memory or the file is over 1 GB). 'codePage' is used only
// when the file is neither marked nor UTF-8 nor UTF-16. Optional outputs: the encoding
// used and the number of SAL_CSL_BADCHAR bytes written.
inline char* SalCslDecode(const unsigned char* d, size_t n, UINT codePage, SalCslEncoding* encOut, size_t* badOut)
{
    if (n > 0x40000000)
        return NULL;
    SalCslEncoding enc = SalCslDetect(d, n);
    if (encOut != NULL)
        *encOut = enc;
    if (badOut != NULL)
        *badOut = 0;
    // worst cases: UTF-8 copies at most n bytes; a UTF-16 unit gives at most 3 bytes (a pair
    // 4), i.e. 1.5 per input byte; a code page byte at most 3 (one BMP character)
    size_t cap = (enc == SAL_CSL_UTF8 || enc == SAL_CSL_UTF8_BOM) ? n : (enc == SAL_CSL_CODEPAGE ? 3 * n : n / 2 * 3 + 1);
    char* buf = (char*)malloc(cap + 1);
    if (buf == NULL)
        return NULL;
    SalCslDetail::COut o = {buf, 0, true, 0};
    switch (enc)
    {
    case SAL_CSL_UTF8:
    case SAL_CSL_UTF8_BOM:
    {
        size_t i = enc == SAL_CSL_UTF8_BOM ? 3 : 0;
        while (i < n)
        {
            int s = SalCslDetail::Wtf8SeqLen(d + i, n - i);
            if (s == 0)
            {
                o.BadChar(); // only in a marked file (an unmarked one is UTF-8 only when valid)
                i++;
            }
            else if (s == 1)
            {
                if (d[i] == 0)
                {
                    size_t j = i;
                    while (j < n && d[j] == 0)
                        j++;
                    o.Nuls(j - i, j == n || d[j] == '\r' || d[j] == '\n');
                    i = j;
                }
                else
                {
                    o.Byte(d[i]);
                    i++;
                }
            }
            else
            {
                if (s == 3 && d[i] == 0xEF && d[i + 1] == 0xBB && d[i + 2] == 0xBF && o.LineStart)
                {
                    i += 3; // a byte order mark at the start of a line (concatenated lists)
                    continue;
                }
                memcpy(o.Buf + o.Len, d + i, s);
                o.Len += s;
                o.LineStart = false;
                i += s;
            }
        }
        break;
    }

    case SAL_CSL_UTF16LE_BOM:
    case SAL_CSL_UTF16BE_BOM:
    case SAL_CSL_UTF16LE:
    case SAL_CSL_UTF16BE:
    {
        bool le = (enc == SAL_CSL_UTF16LE_BOM || enc == SAL_CSL_UTF16LE);
        size_t start = (enc == SAL_CSL_UTF16LE_BOM || enc == SAL_CSL_UTF16BE_BOM) ? 2 : 0;
        size_t units = (n - start) / 2;
        WCHAR* w = (WCHAR*)malloc((units + 1) * sizeof(WCHAR));
        if (w == NULL)
        {
            free(buf);
            return NULL;
        }
        for (size_t u = 0; u < units; u++)
        {
            const unsigned char* p = d + start + 2 * u;
            w[u] = le ? (WCHAR)(p[0] | (p[1] << 8)) : (WCHAR)((p[0] << 8) | p[1]);
        }
        o.Units(w, units);
        free(w);
        if (((n - start) & 1) && d[n - 1] != 0)
            o.BadChar(); // a cut-off last unit (a lone NUL byte after the text is padding)
        break;
    }

    default: // SAL_CSL_CODEPAGE
    {
        // exact conversion only (MB_ERR_INVALID_CHARS; a code page -> UTF-16 conversion has no
        // best fit, every defined byte has exactly one character)
        int wl = n > 0 ? MultiByteToWideChar(codePage, MB_ERR_INVALID_CHARS, (const char*)d, (int)n, NULL, 0) : 0;
        if (n == 0 || wl > 0)
        {
            if ((size_t)wl * 3 > cap) // a code page that yields more units than bytes (none known)
            {
                char* bigger = (char*)realloc(buf, (size_t)wl * 3 + 1);
                if (bigger == NULL)
                {
                    free(buf);
                    return NULL;
                }
                buf = bigger;
                o.Buf = buf;
            }
            WCHAR* w = (WCHAR*)malloc(((size_t)wl + 1) * sizeof(WCHAR));
            if (w == NULL)
            {
                free(buf);
                return NULL;
            }
            if (n > 0)
                MultiByteToWideChar(codePage, MB_ERR_INVALID_CHARS, (const char*)d, (int)n, w, wl);
            o.Units(w, (size_t)wl);
            free(w);
        }
        else
        {
            // something does not convert (a double-byte code page with a broken sequence, or a
            // byte the code page does not define): character by character, each failure one
            // SAL_CSL_BADCHAR - the rest of the line (its checksum, its line end) stays
            size_t i = 0;
            while (i < n)
            {
                if (d[i] == 0)
                {
                    size_t j = i;
                    while (j < n && d[j] == 0)
                        j++;
                    o.Nuls(j - i, j == n || d[j] == '\r' || d[j] == '\n');
                    i = j;
                    continue;
                }
                WCHAR w[4];
                int r = 0;
                int used = 1;
                if (i + 1 < n && IsDBCSLeadByteEx(codePage, d[i]))
                {
                    r = MultiByteToWideChar(codePage, MB_ERR_INVALID_CHARS, (const char*)d + i, 2, w, 4);
                    used = 2;
                }
                if (r <= 0)
                {
                    used = 1;
                    r = MultiByteToWideChar(codePage, MB_ERR_INVALID_CHARS, (const char*)d + i, 1, w, 4);
                }
                if (r > 0)
                    o.Units(w, (size_t)r);
                else
                    o.BadChar();
                i += used;
            }
        }
        break;
    }
    }
    buf[o.Len] = 0;
    if (badOut != NULL)
        *badOut = o.Bad;
    return buf;
}

// rule 3, first half: FALSE when a name taken from a list cannot name a file and must be
// reported "missing" without any look-up - it holds a part that could not be converted, a
// control character, or a character that the directory look-up takes as a wildcard
// (* ? < > ") or that no Windows name holds (|). A '?' is what a code-page tool writes for
// a character outside its code page: looked up, "???.txt" found "abc.txt". A ':' is refused
// too, except right after the drive letter of "X:\..." / "X:/...": "file.txt:secret" names
// an alternate data stream and "C:name" the current folder of another drive.
//
// DEVICE SAFETY relies on this rule together with SalCslBuildPath (and the plug-in's "\\?\"
// prefixing of absolute paths): every device namespace spelling ("\\?\...", "\\.\pipe\x",
// "\\?\GLOBALROOT\...") either holds a '?' (refused here) or starts with two separators
// (refused by SalCslBuildPath unless it is the list's own share). Never relax '?' or the
// two-separator rule without a device guard - opening a named pipe would hang the worker.
inline BOOL SalCslNameUsable(const char* name)
{
    if (name == NULL || *name == 0)
        return FALSE;
    for (const unsigned char* s = (const unsigned char*)name; *s != 0; s++)
    {
        unsigned char c = *s;
        if (c < 0x20 || c == SAL_CSL_BADCHAR || c == '*' || c == '?' || c == '<' || c == '>' ||
            c == '"' || c == '|')
            return FALSE;
        if (c == ':' && !(s == (const unsigned char*)name + 1 && (s[1] == '\\' || s[1] == '/') &&
                          ((name[0] >= 'A' && name[0] <= 'Z') || (name[0] >= 'a' && name[0] <= 'z'))))
            return FALSE;
    }
    return TRUE;
}

// GNU coreutils (md5sum, sha*sum - also Git for Windows) start a line with '\' when the
// name holds a backslash or a line break, and escape those in the name: "\\" = '\',
// "\n" = line feed, "\r" = carriage return. Unescapes 'name' in place. Like coreutils, any
// other escape and a lone backslash at the end make the line invalid: the name gets a
// SAL_CSL_BADCHAR there (reported missing). (A line break makes the name unusable, see above.)
inline void SalCslUnescapeName(char* name)
{
    char* w = name;
    for (const char* r = name; *r != 0; r++)
    {
        if (*r == '\\')
        {
            if (r[1] == '\\' || r[1] == 'n' || r[1] == 'r')
            {
                r++;
                *w++ = (*r == '\\') ? '\\' : (*r == 'n' ? '\n' : '\r');
            }
            else
            {
                unsigned char bad = SAL_CSL_BADCHAR;
                *w++ = (char)bad;
            }
        }
        else
            *w++ = *r;
    }
    *w = 0;
}

namespace SalCslDetail
{
    // length of the root of a Windows path: "X:\" = 3, "\\server\share" up to the end of the
    // share name, otherwise 0 (a path without a root)
    inline size_t RootLen(const char* p)
    {
        if (((p[0] >= 'A' && p[0] <= 'Z') || (p[0] >= 'a' && p[0] <= 'z')) && p[1] == ':' && p[2] == '\\')
            return 3;
        if (p[0] == '\\' && p[1] == '\\')
        {
            const char* s = p + 2;
            while (*s != 0 && *s != '\\')
                s++; // server
            if (*s == '\\')
            {
                s++;
                while (*s != 0 && *s != '\\')
                    s++; // share
            }
            return (size_t)(s - p);
        }
        return 0;
    }
    // "X:\" / "X:/" (a drive) or two separators of any kind ("\\", "//", "/\", "\/" - a UNC
    // or device path: "\\server\share", "\\?\UNC\...", "\\.\pipe\...")
    inline bool IsAbsoluteName(const char* n)
    {
        if (((n[0] >= 'A' && n[0] <= 'Z') || (n[0] >= 'a' && n[0] <= 'z')) && n[1] == ':' && (n[2] == '\\' || n[2] == '/'))
            return true;
        return (n[0] == '\\' || n[0] == '/') && (n[1] == '\\' || n[1] == '/');
    }
    // TRUE when the two roots ("X:\" or "\\server\share", UTF-8) are one root by the file
    // system's ordinal case-insensitive rule (feature 092); anything not convertible differs
    inline bool SameRoot(const char* a, size_t al, const char* b, size_t bl)
    {
        if (al == 0 || bl == 0 || al > 1000 || bl > 1000)
            return false;
        WCHAR wa[1024], wb[1024];
        int la = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, a, (int)al, wa, 1024);
        int lb = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, b, (int)bl, wb, 1024);
        return la > 0 && lb > 0 && CompareStringOrdinal(wa, la, wb, lb, TRUE) == CSTR_EQUAL;
    }
} // namespace SalCslDetail

// results of SalCslBuildPath
#define SAL_CSL_PATH_OK 1
#define SAL_CSL_PATH_TOOLONG 0  // 'out' too small
#define SAL_CSL_PATH_FOREIGN -1 // an absolute name outside the list's own drive or share

// rule 3, second half: the path of the file a list line names. 'listDir' is the list's own
// folder (UTF-8, as the panel shows it). A relative 'name' is taken inside it (a single
// leading separator is skipped, as always). An absolute name ("X:\...", or any name that
// starts with two separators: "\\server\share\...", "//host/...", "\\?\UNC\...",
// "\\.\pipe\...") is used ONLY when its root is the list's own root (the same drive, the same
// "\\server\share"); otherwise SAL_CSL_PATH_FOREIGN and 'out' is empty - the caller reports
// the name missing WITHOUT touching the file system: a list must never make the program
// connect to a server (an SMB / WebDAV look-up sends the user's credentials - an NTLM hash -
// to any host a hostile list names) nor reach a drive or a device the list is not on.
// '/' is a separator; empty and "." components are dropped and ".." removes the component
// before it, never climbing above the root (the drive or the share). Nothing else changes:
// the file system decides which file the result names.
inline int SalCslBuildPath(const char* listDir, const char* name, char* out, size_t outSize)
{
    if (listDir == NULL || name == NULL || out == NULL || outSize == 0)
        return SAL_CSL_PATH_TOOLONG;
    out[0] = 0;
    size_t dl = strlen(listDir), nl = strlen(name);
    char* t = (char*)malloc(dl + nl + 2);
    if (t == NULL)
        return SAL_CSL_PATH_TOOLONG;
    size_t tl = 0;
    bool absolute = SalCslDetail::IsAbsoluteName(name);
    if (!absolute)
    {
        memcpy(t, listDir, dl);
        tl = dl;
        t[tl++] = '\\';
    }
    for (size_t i = 0; i < nl; i++)
        t[tl++] = name[i] == '/' ? '\\' : name[i];
    t[tl] = 0;

    size_t root = SalCslDetail::RootLen(t);
    if (absolute)
    {
        size_t lroot = SalCslDetail::RootLen(listDir);
        size_t ln = lroot, tn = root; // compare "X:" / "\\server\share" without a trailing separator
        if (ln > 0 && listDir[ln - 1] == '\\')
            ln--;
        if (tn > 0 && t[tn - 1] == '\\')
            tn--;
        if (root == 0 || !SalCslDetail::SameRoot(listDir, ln, t, tn))
        {
            free(t);
            return SAL_CSL_PATH_FOREIGN;
        }
    }
    size_t ol = 0;
    BOOL ok = TRUE;
    // the root as it is ("X:\" or "\\server\share")
    if (root + 1 > outSize)
        ok = FALSE;
    else
    {
        memcpy(out, t, root);
        ol = root;
    }
    size_t base = ol; // ".." never removes anything before this
    size_t i = root;
    while (ok && i < tl)
    {
        while (i < tl && t[i] == '\\')
            i++;
        size_t s = i;
        while (i < tl && t[i] != '\\')
            i++;
        size_t cl = i - s;
        if (cl == 0 || (cl == 1 && t[s] == '.'))
            continue;
        if (cl == 2 && t[s] == '.' && t[s + 1] == '.')
        {
            while (ol > base && out[ol - 1] != '\\')
                ol--;
            if (ol > base)
                ol--; // the separator before the removed component
            if (ol < base)
                ol = base;
            continue;
        }
        // a separator unless the output ends with one already ("X:\") or is empty
        bool sep = ol > 0 && out[ol - 1] != '\\';
        if (ol + (sep ? 1 : 0) + cl + 1 > outSize)
        {
            ok = FALSE;
            break;
        }
        if (sep)
            out[ol++] = '\\';
        memcpy(out + ol, t + s, cl);
        ol += cl;
    }
    free(t);
    if (!ok)
    {
        out[0] = 0;
        return SAL_CSL_PATH_TOOLONG;
    }
    out[ol] = 0;
    return SAL_CSL_PATH_OK;
}
