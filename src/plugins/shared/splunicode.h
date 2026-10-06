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
#include <wchar.h> // wmemcmp (feature 100)

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
        // feature 116: a failed conversion may have written part of the text (a password, too)
        // into the buffer - nothing of it stays there
        SecureZeroMemory(buf, (size_t)bufSize);
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

// feature 100: sets a window's title from UTF-16 text so that it keeps characters outside
// the system code page also on a code-page ("ANSI") window - a plug-in's viewer window
// (winliblt's CWindow class) is one, and SetWindowTextW on it stores the title through the
// code page ('?' for every character outside it). The core's twin is SalSetWindowTitleW
// (src/common/winlib.cpp), same rule: SetWindowTextW as always - every window procedure sees
// WM_SETTEXT - and then, only for a top-level window (WS_CHILD clear) owned by the calling
// thread, the stored title (InternalGetWindowText) is compared with the text; when they differ
// the UTF-16 text is stored with DefWindowProcW(WM_SETTEXT). Child windows and controls and
// other threads' windows get exactly SetWindowTextW (a worker thread must hand the title to
// the window's own thread). A read-back in the owning process
// with GetWindowTextW still sees '?' - compare with InternalGetWindowText.
inline BOOL SplSetWindowTitleW(HWND hWnd, const WCHAR* text)
{
    if (text == NULL)
        text = L"";
    BOOL ret = SetWindowTextW(hWnd, text);
    if (!ret || hWnd == NULL)
        return ret;
    if ((GetWindowLongPtrW(hWnd, GWL_STYLE) & WS_CHILD) != 0) // top-level only (no WS_CAPTION test)
        return ret;
    if (GetWindowThreadProcessId(hWnd, NULL) != GetCurrentThreadId())
        return ret;
    size_t len = wcslen(text);
    if (len > 0x7FFFFFF0)
        return ret;
    WCHAR stackBuf[512];
    WCHAR* stored = len + 2 <= sizeof(stackBuf) / sizeof(stackBuf[0]) ? stackBuf : (WCHAR*)malloc((len + 2) * sizeof(WCHAR));
    if (stored == NULL)
        return ret;
    stored[0] = 0;
    int got = InternalGetWindowText(hWnd, stored, (int)len + 2); // a longer stored title reads len + 1
    BOOL same = got == (int)len && wmemcmp(stored, text, len) == 0;
    if (stored != stackBuf)
        free(stored);
    if (!same)
        DefWindowProcW(hWnd, WM_SETTEXT, 0, (LPARAM)text);
    return ret;
}

// feature 104: shortens a text of 'len' units (terminated, in place) that is longer than 1,024
// units to its first 32 units + "..." + its last 960 units, never between the halves of a
// surrogate pair; returns the new length (the old one when nothing was done). For a path drawn
// with DT_PATH_ELLIPSIS, whose cost grows with the square of the length (feature 102: 28 s for
// 30,000 units): the ellipsis then fits the shortened text as for any short name.
inline int SplShortenLongTextW(WCHAR* text, int len)
{
    const int head = 32, tail = 960;
    if (text == NULL || len <= 1024)
        return len;
    int h = head;
    if (text[h - 1] >= 0xD800 && text[h - 1] <= 0xDBFF) // do not end the head with a high surrogate
        h--;
    int t = len - tail;
    if (text[t] >= 0xDC00 && text[t] <= 0xDFFF) // do not start the tail with a low surrogate
        t++;
    text[h] = L'.';
    text[h + 1] = L'.';
    text[h + 2] = L'.';
    memmove(text + h + 3, text + t, (len - t + 1) * sizeof(WCHAR));
    return h + 3 + (len - t);
}

// feature 104: draws the text of window 'hWnd' (a static label that shows a file name or a
// path) into 'hdc' as UTF-16, so it keeps characters outside the system code page. The ZIP and
// CAB plug-ins paint such labels themselves with DT_PATH_ELLIPSIS; they read the text with
// GetWindowTextA, which gives '?' or a best-fit look-alike ("voila" for "voil<U+00E0>"), and cut
// it at 259 bytes. A long text is shortened first (SplShortenLongTextW). Returns DrawTextW's result.
inline int SplDrawWindowTextW(HWND hWnd, HDC hdc, RECT* r, UINT format)
{
    int len = GetWindowTextLengthW(hWnd);
    if (len < 0)
        len = 0;
    WCHAR stackBuf[1100];
    WCHAR* text = len + 1 <= (int)(sizeof(stackBuf) / sizeof(stackBuf[0])) ? stackBuf : (WCHAR*)malloc((len + 1) * sizeof(WCHAR));
    if (text == NULL)
        return 0;
    text[0] = 0;
    len = GetWindowTextW(hWnd, text, len + 1);
    len = SplShortenLongTextW(text, len);
    int ret = DrawTextW(hdc, text, len, r, format);
    if (text != stackBuf)
        free(text);
    return ret;
}

// ---------------------------------------------------------------------------
// Feature 121: cutting UTF-8 at a whole character, and display text of either
// encoding. A byte-count clamp (lstrcpyn, _snprintf_s with _TRUNCATE, a fixed
// field) can cut a multi-byte character in half; the torn tail then makes the
// strict probe fail and the whole text is shown through the code page.

// drops a trailing INCOMPLETE UTF-8 sequence in place; a complete character at the
// end is left alone (the core's SalU8TrimIncompleteTail), so it is safe to call on
// any UTF-8 buffer
inline void SplU8TrimTornTail(char* buf)
{
    if (buf == NULL)
        return;
    size_t len = strlen(buf);
    size_t i = len;
    while (i > 0 && ((unsigned char)buf[i - 1] & 0xC0) == 0x80)
        i--; // walk back over the continuation bytes
    if (i > 0)
    {
        unsigned char lead = (unsigned char)buf[i - 1];
        if (lead >= 0xC0) // a lead byte: is its sequence complete?
        {
            size_t seqLen = lead >= 0xF0 ? 4 : (lead >= 0xE0 ? 3 : 2);
            if (len - (i - 1) < seqLen)
                buf[i - 1] = 0; // cut: drop it whole
        }
    }
}

// lstrcpyn(dst, src, dstSize) that never leaves a torn UTF-8 character at the end
// (only a copy that had to be cut is trimmed - code-page text that fits is untouched)
inline void SplU8CopyTrunc(char* dst, int dstSize, const char* src)
{
    if (dst == NULL || dstSize <= 0)
        return;
    if (src == NULL)
    {
        dst[0] = 0;
        return;
    }
    size_t srcLen = strlen(src);
    if (srcLen < (size_t)dstSize)
    {
        memcpy(dst, src, srcLen + 1);
        return;
    }
    memcpy(dst, src, (size_t)dstSize - 1);
    dst[dstSize - 1] = 0;
    SplU8TrimTornTail(dst);
}

// text to show that is UTF-8 (WTF-8) or code-page text (a resource string, a
// FormatMessageA text) -> UTF-16; a UTF-8 text cut by a byte clamp is shown without
// its torn last character instead of whole through the code page. free() the result;
// NULL only on low memory.
inline WCHAR* SplDisplayTextToWAlloc(const char* text)
{
    if (text == NULL)
        text = "";
    WCHAR* w = SplU8ToWAlloc(text);
    if (w != NULL)
        return w;
    size_t len = strlen(text);
    char* copy = (char*)malloc(len + 1);
    if (copy != NULL)
    {
        memcpy(copy, text, len + 1);
        SplU8TrimTornTail(copy);
        size_t kept = strlen(copy);
        // it had a torn tail: is the rest UTF-8? Only with evidence that the text IS UTF-8 - the cut
        // sequence had a continuation byte, or the rest holds a non-ASCII character (review NIT 1:
        // code-page text ending in one letter >= 0xC0, "Fichier utilis<E9>", is not a torn tail)
        if (kept < len && (len - kept >= 2 || !SplIsASCII(copy)))
            w = SplU8ToWAlloc(copy);
        free(copy);
        if (w != NULL)
            return w;
    }
    int n = MultiByteToWideChar(CP_ACP, 0, text, -1, NULL, 0);
    if (n <= 0)
        n = 1;
    w = (WCHAR*)malloc(n * sizeof(WCHAR));
    if (w != NULL && MultiByteToWideChar(CP_ACP, 0, text, -1, w, n) <= 0)
        w[0] = 0;
    return w;
}
