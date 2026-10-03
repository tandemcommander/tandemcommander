// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "TreeMap.FileData.CZFile.h"

// ****************************************************************************
//
// Text output on the W layer
//
// Since plugin interface 104 every file name crossing the Salamander interface is UTF-8,
// so the names stored in the tree are UTF-8 as well. The localized strings loaded from the
// language module are ANSI. These helpers convert the text to UTF-16 (UTF-8 first, ANSI as
// a fallback) and draw/measure it via the W GDI, which is the only way non-ASCII names can
// be rendered correctly.
//

#define ZTEXT_STACKBUF 512

// TCHAR (UTF-8 or ANSI) -> UTF-16; returns the number of characters, 'buf' must be freed with
// ZTextFreeW() when it differs from 'stackBuf'
inline WCHAR* ZTextToW(const TCHAR* text, int len, WCHAR* stackBuf, int stackBufChars, int* wLen)
{
    *wLen = 0;
    if (text == NULL || len < 0)
        return stackBuf;
    WCHAR* w = stackBuf;
    if (len + 1 > stackBufChars)
    {
        w = (WCHAR*)malloc((len + 1) * sizeof(WCHAR));
        if (w == NULL)
            return stackBuf;
    }
    int l = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, len, w, len + 1);
    if (l == 0) // not valid UTF-8 (e.g. a localized ANSI string) -> fall back to ANSI
        l = MultiByteToWideChar(CP_ACP, 0, text, len, w, len + 1);
    *wLen = l;
    return w;
}

inline void ZTextFreeW(WCHAR* w, WCHAR* stackBuf)
{
    if (w != stackBuf)
        free(w);
}

inline BOOL ZExtTextOut(HDC hdc, int x, int y, UINT options, const RECT* rect,
                        const TCHAR* text, UINT len, const INT* dx)
{
    if (text == NULL || len == 0)
        return ExtTextOutW(hdc, x, y, options, rect, NULL, 0, dx);
    WCHAR stackBuf[ZTEXT_STACKBUF];
    int wLen;
    WCHAR* w = ZTextToW(text, (int)len, stackBuf, ZTEXT_STACKBUF, &wLen);
    BOOL ret = ExtTextOutW(hdc, x, y, options, rect, w, (UINT)wLen, dx);
    ZTextFreeW(w, stackBuf);
    return ret;
}

inline BOOL ZTextOut(HDC hdc, int x, int y, const TCHAR* text, int len)
{
    WCHAR stackBuf[ZTEXT_STACKBUF];
    int wLen;
    WCHAR* w = ZTextToW(text, len, stackBuf, ZTEXT_STACKBUF, &wLen);
    BOOL ret = TextOutW(hdc, x, y, w, wLen);
    ZTextFreeW(w, stackBuf);
    return ret;
}

inline BOOL ZGetTextExtentPoint32(HDC hdc, const TCHAR* text, int len, SIZE* size)
{
    WCHAR stackBuf[ZTEXT_STACKBUF];
    int wLen;
    WCHAR* w = ZTextToW(text, len, stackBuf, ZTEXT_STACKBUF, &wLen);
    BOOL ret = GetTextExtentPoint32W(hdc, w, wLen, size);
    ZTextFreeW(w, stackBuf);
    return ret;
}

inline BOOL ZSetWindowText(HWND hWnd, const TCHAR* text)
{
    WCHAR stackBuf[ZTEXT_STACKBUF];
    int wLen;
    WCHAR* w = ZTextToW(text, (int)_tcslen(text), stackBuf, ZTEXT_STACKBUF, &wLen);
    w[wLen] = 0;
    // feature 100: the DiskMap window is a code-page window - SetWindowTextW stored its title
    // through the code page ('?' for a path outside it); SplSetWindowTitleW keeps it exact
    // (splunicode.h comes with precomp.h)
    BOOL ret = SplSetWindowTitleW(hWnd, w);
    ZTextFreeW(w, stackBuf);
    return ret;
}

// number of UTF-16 characters the first 'bytePos' bytes of the (UTF-8) text expand to;
// used to map positions inside the UTF-8 string onto the W string used for drawing
inline int ZU8PosToWPos(const TCHAR* text, int bytePos)
{
    if (bytePos <= 0)
        return 0;
    int l = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, bytePos, NULL, 0);
    if (l == 0)
        l = MultiByteToWideChar(CP_ACP, 0, text, bytePos, NULL, 0);
    return l;
}

// Like GetTextExtentExPoint, but for a UTF-8 (or ANSI-fallback) string: it measures via the W
// GDI and stores the cumulative widths BYTE-indexed (dxByte[i] = width of text[0..i]), which is
// how the CDirectoryLine path code consumes them (its node offsets are byte positions inside the
// UTF-8 path). 'dxByte' must have at least 'byteLen' entries. Returns TRUE on success.
inline BOOL ZGetTextExtentByteDx(HDC hdc, const TCHAR* text, int byteLen, int* dxByte, SIZE* size)
{
    size->cx = 0;
    size->cy = 0;
    if (byteLen <= 0)
        return TRUE;
    WCHAR stackBuf[ZTEXT_STACKBUF];
    int wLen;
    WCHAR* w = ZTextToW(text, byteLen, stackBuf, ZTEXT_STACKBUF, &wLen);
    BOOL ret = FALSE;
    int* wdx = (int*)malloc((wLen > 0 ? wLen : 1) * sizeof(int));
    if (wdx != NULL && GetTextExtentExPointW(hdc, w, wLen, 0, NULL, wdx, size))
    {
        // map each byte of the UTF-8 string onto the width of the code point it belongs to
        int b = 0;
        for (int j = 0; j < wLen && b < byteLen; j++)
        {
            int cpBytes, wUnits;
            if (w[j] >= 0xD800 && w[j] <= 0xDBFF && j + 1 < wLen)
            {
                cpBytes = 4; // supplementary code point = surrogate pair = 4 UTF-8 bytes
                wUnits = 2;
            }
            else
            {
                WCHAR c = w[j];
                cpBytes = c < 0x80 ? 1 : (c < 0x800 ? 2 : 3);
                wUnits = 1;
            }
            int width = wdx[j + wUnits - 1];
            for (int k = 0; k < cpBytes && b < byteLen; k++)
                dxByte[b++] = width;
            if (wUnits == 2)
                j++; // skip the low surrogate
        }
        while (b < byteLen) // ANSI fallback path (1 byte == 1 wide unit) or rounding safety
            dxByte[b++] = size->cx;
        ret = TRUE;
    }
    free(wdx);
    ZTextFreeW(w, stackBuf);
    return ret;
}

class CStringFormatter;

class CZString
{
protected:
    TCHAR* _s;
    size_t _l;

public:
    explicit CZString(TCHAR const* s)
    {
        this->_l = _tcslen(s);
        this->_s = (TCHAR*)malloc((this->_l + 1) * sizeof TCHAR);
        _tcscpy(this->_s, s);
    }

    explicit CZString(CZFile* file)
    {
        TCHAR buff[2 * MAX_PATH + 1];
        this->_l = file->GetFullName(buff, ARRAYSIZE(buff));
        this->_s = (TCHAR*)malloc((this->_l + 1) * sizeof TCHAR);
        _tcscpy(this->_s, buff);
    }

    ~CZString()
    {
        free(this->_s);
        this->_s = NULL;
        this->_l = 0;
    }
    TCHAR const* GetString() const { return this->_s; }
    size_t GetLength() const { return this->_l; }
};

class CZStringBuffer
{
    friend class CStringFormatter;

protected:
    TCHAR* _s;
    size_t _l; //length of the string
    size_t _c; //buffer size in TCHARs
public:
    explicit CZStringBuffer(TCHAR const* s)
    {
        this->_l = _tcslen(s);
        this->_c = this->_l + 1;
        this->_s = (TCHAR*)malloc(this->_c * sizeof TCHAR);
    }
    explicit CZStringBuffer(size_t size)
    {
        this->_l = 0;
        this->_c = size;
        this->_s = (TCHAR*)malloc(this->_c * sizeof TCHAR);
        *this->_s = TEXT('\0');
    }
    ~CZStringBuffer()
    {
        free(this->_s);
        this->_s = NULL;
        this->_c = 0;
        this->_l = 0;
    }
    TCHAR const* GetString() const { return this->_s; }
    size_t GetLength() const { return this->_l; }
    size_t GetBuffSize() const { return this->_c; }

    BOOL EndsWith(TCHAR chr) const
    {
        if (this->_l == 0)
            return FALSE;
        return (this->_s[this->_l - 1] == chr);
    }
    BOOL StartsWith(TCHAR chr) const
    {
        if (this->_l == 0)
            return FALSE;
        return (this->_s[0] == chr);
    }
    BOOL IsCharAt(TCHAR chr, size_t pos) const
    {
        if (this->_l < pos)
            return FALSE;
        return (this->_s[pos] == chr);
    }

    CZStringBuffer* Append(TCHAR const* s)
    {
        size_t len = _tcslen(s);

        return this->AppendAt(s, len, this->_l);
    }

    CZStringBuffer* Append(TCHAR const* s, size_t len)
    {
        return this->AppendAt(s, len, this->_l);
    }

    CZStringBuffer* Append(TCHAR c)
    {
        return this->AppendAt(c, this->_l);
    }

    CZStringBuffer* AppendAt(TCHAR const* s, int pos)
    {
        size_t len = _tcslen(s);

        return this->AppendAt(s, len, pos);
    }
    CZStringBuffer* AppendAt(TCHAR const* s, size_t len, size_t pos)
    {
        int p = (int)min(pos, this->_l);
        if (len + p > this->_c)
            return this; //TODO!

        //len = this->_c - this->_l - 1;
        _tcscpy(&this->_s[p], s);
        //memcpy(this->_s[this->_l], s, len * sizeof TCHAR);

        this->_l = len + p;
        this->_s[this->_l] = TEXT('\0');

        return this;
    }
    CZStringBuffer* AppendAt(TCHAR c, size_t pos)
    {
        size_t p = min(pos, this->_l);
        if (p >= this->_c)
            return this; //TODO!

        this->_s[p] = c;

        this->_l = p + 1;
        this->_s[this->_l] = TEXT('\0');

        return this;
    }
    CZStringBuffer* Append(CZString const* s)
    {
        return this->AppendAt(s->GetString(), s->GetLength(), this->_l);
    }
    CZStringBuffer* AppendAt(CZString const* s, int pos)
    {
        return this->AppendAt(s->GetString(), s->GetLength(), pos);
    }

    CZStringBuffer* Left(size_t len)
    {
        if (len > this->_l)
            len = this->_l;

        this->_l = len;
        this->_s[this->_l] = TEXT('\0');

        return this;
    }
    size_t GetSubString(size_t pos, size_t length, TCHAR* buff, size_t bufflen)
    {
        if (pos >= this->_l)
            return 0;

        if (length >= bufflen)
            length = bufflen - 1;
        if (pos + length > this->_l)
            length = this->_l - pos;

        //_tcscpy(&this->_s[p], s);
        memcpy(buff, &this->_s[pos], length * sizeof TCHAR);
        buff[length] = TEXT('\0');

        return length;
    }
};
