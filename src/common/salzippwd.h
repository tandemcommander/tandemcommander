// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salzippwd.h
//
// The byte forms of a typed ZIP password (feature 094, contract
// specs/094-plugin-password-encoding/contracts/zip-password-forms.md).
// Header-only, no globals, testable in saltests.
//
// ZIP encryption works on password BYTES and no standard says how typed text
// becomes bytes. The typed text is UTF-16; from it:
//
//   acp      the text in the system code page, strict (no best-fit mapping,
//            no default character) - exists only for a representable text;
//            what every version wrote for such a text and what 7-Zip opens
//   oem      'acp' through CharToOemBuffA - what earlier versions tried second
//   utf8     the text in UTF-8 (WTF-8 for an unpaired surrogate)
//   oldread  what versions up to 0.1.8 read from the field: GetDlgItemTextA
//            with a count of 255, i.e. the code-page conversion with best-fit
//            mapping and '?' for everything else, cut to 254 bytes. For a
//            representable text of up to 254 bytes it equals 'acp'.
//
// Packing uses ONE form: 'acp' when representable, otherwise 'utf8'. A
// self-extracting archive gets 'oldread': the unchanged stub reads its own
// prompt exactly that way.
// Unpacking tries acp, oem, utf8, oldread - each distinct byte string once.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// the password fields accept 255 characters (MAX_PASSWORD - 1 of the plug-in)
#define SALZIPPWD_MAX_CHARS 255
// one form: 255 UTF-16 units give at most 765 bytes of UTF-8, 510 of a DBCS page
#define SALZIPPWD_FORM_BUF 768
// what the old read kept: GetDlgItemTextA(..., MAX_PASSWORD - 1) = 254 bytes
#define SALZIPPWD_OLDREAD_BYTES 254

#define SALZIPPWD_ACP 0
#define SALZIPPWD_OEM 1
#define SALZIPPWD_UTF8 2
#define SALZIPPWD_OLDREAD 3
#define SALZIPPWD_FORMS 4

struct CSalZipPwdForm
{
    int Kind;                      // SALZIPPWD_xxx
    int Len;                       // bytes, without the terminator
    char Bytes[SALZIPPWD_FORM_BUF]; // zero-terminated
};

struct CSalZipPwdCandidates
{
    int Count;
    CSalZipPwdForm Forms[SALZIPPWD_FORMS];
};

inline void SalZipPwdWipe(CSalZipPwdCandidates* c)
{
    if (c != NULL)
        SecureZeroMemory(c, sizeof(*c));
}

inline UINT SalZipPwdResolveCP(UINT codePage)
{
    return codePage == CP_ACP ? GetACP() : (codePage == CP_OEMCP ? GetOEMCP() : codePage);
}

// units of 'typed' counted up to SALZIPPWD_MAX_CHARS (the field's limit)
inline int SalZipPwdUnits(const wchar_t* typed)
{
    int n = 0;
    if (typed != NULL)
        while (n < SALZIPPWD_MAX_CHARS && typed[n] != 0)
            n++;
    return n;
}

// UTF-8 of 'typed'; an unpaired surrogate is written as its 3-byte sequence
// (WTF-8, the house rule of feature 066). Returns the length or -1.
inline int SalZipPwdUtf8(const wchar_t* typed, char* out, int outSize)
{
    if (out == NULL || outSize <= 0)
        return -1;
    int units = SalZipPwdUnits(typed);
    int n = 0;
    for (int i = 0; i < units; i++)
    {
        unsigned int c = (unsigned short)typed[i];
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < units &&
            (unsigned short)typed[i + 1] >= 0xDC00 && (unsigned short)typed[i + 1] <= 0xDFFF)
        {
            c = 0x10000 + ((c - 0xD800) << 10) + ((unsigned short)typed[i + 1] - 0xDC00);
            i++;
        }
        int need = c < 0x80 ? 1 : (c < 0x800 ? 2 : (c < 0x10000 ? 3 : 4));
        if (n + need >= outSize)
        {
            SecureZeroMemory(out, outSize);
            return -1;
        }
        if (need == 1)
            out[n++] = (char)c;
        else if (need == 2)
        {
            out[n++] = (char)(0xC0 | (c >> 6));
            out[n++] = (char)(0x80 | (c & 0x3F));
        }
        else if (need == 3)
        {
            out[n++] = (char)(0xE0 | (c >> 12));
            out[n++] = (char)(0x80 | ((c >> 6) & 0x3F));
            out[n++] = (char)(0x80 | (c & 0x3F));
        }
        else
        {
            out[n++] = (char)(0xF0 | (c >> 18));
            out[n++] = (char)(0x80 | ((c >> 12) & 0x3F));
            out[n++] = (char)(0x80 | ((c >> 6) & 0x3F));
            out[n++] = (char)(0x80 | (c & 0x3F));
        }
    }
    out[n] = 0;
    return n;
}

// the strict code-page form: the length, or -1 when 'typed' is not
// representable in 'codePage' (contract Z1) or does not fit
inline int SalZipPwdAcp(const wchar_t* typed, char* out, int outSize, UINT codePage = CP_ACP)
{
    if (out == NULL || outSize <= 0)
        return -1;
    out[0] = 0;
    int units = SalZipPwdUnits(typed);
    if (units == 0)
        return 0;
    UINT cp = SalZipPwdResolveCP(codePage);
    int n;
    if (cp == CP_UTF8) // the "UTF-8 system code page" setting: the two flags below are not allowed
        n = WideCharToMultiByte(cp, WC_ERR_INVALID_CHARS, typed, units, out, outSize - 1, NULL, NULL);
    else
    {
        BOOL usedDefault = FALSE;
        n = WideCharToMultiByte(cp, WC_NO_BEST_FIT_CHARS, typed, units, out, outSize - 1, NULL, &usedDefault);
        if (usedDefault)
            n = 0;
    }
    if (n <= 0 || memchr(out, 0, n) != NULL)
    {
        SecureZeroMemory(out, outSize);
        return -1;
    }
    out[n] = 0;
    return n;
}

inline BOOL SalZipPwdRepresentable(const wchar_t* typed, UINT codePage = CP_ACP)
{
    char tmp[SALZIPPWD_FORM_BUF];
    BOOL ok = SalZipPwdAcp(typed, tmp, sizeof(tmp), codePage) >= 0;
    SecureZeroMemory(tmp, sizeof(tmp));
    return ok;
}

// what the old code read from the field (see the head of this file); the
// length, or -1 on a failure of the conversion
inline int SalZipPwdOldRead(const wchar_t* typed, char* out, int outSize, UINT codePage = CP_ACP)
{
    if (out == NULL || outSize <= 0)
        return -1;
    out[0] = 0;
    int units = SalZipPwdUnits(typed);
    if (units == 0)
        return 0;
    UINT cp = SalZipPwdResolveCP(codePage);
    char all[SALZIPPWD_FORM_BUF];
    int n = WideCharToMultiByte(cp, 0, typed, units, all, sizeof(all) - 1, NULL, NULL);
    if (n <= 0)
    {
        SecureZeroMemory(all, sizeof(all));
        return -1;
    }
    if (n > SALZIPPWD_OLDREAD_BYTES)
        n = SALZIPPWD_OLDREAD_BYTES;
    all[n] = 0;
    n = (int)strlen(all); // the old consumers stopped at a zero byte
    if (n >= outSize)
        n = outSize - 1;
    memcpy(out, all, n);
    out[n] = 0;
    SecureZeroMemory(all, sizeof(all));
    return n;
}

// 'acp' -> OEM, as CharToOemBuffA does it; for a code page pair given
// explicitly (tests) the same conversion through UTF-16
inline int SalZipPwdOem(const char* acp, int acpLen, char* out, int outSize,
                        UINT codePage = CP_ACP, UINT oemCodePage = CP_OEMCP)
{
    if (out == NULL || outSize <= 0 || acp == NULL || acpLen < 0 || acpLen >= outSize)
        return -1;
    out[0] = 0;
    if (acpLen == 0)
        return 0;
    if (codePage == CP_ACP && oemCodePage == CP_OEMCP)
    {
        if (!CharToOemBuffA(acp, out, (DWORD)acpLen))
            return -1;
        out[acpLen] = 0;
        return (int)strlen(out);
    }
    wchar_t w[SALZIPPWD_FORM_BUF];
    int wn = MultiByteToWideChar(SalZipPwdResolveCP(codePage), 0, acp, acpLen, w, SALZIPPWD_FORM_BUF);
    int n = wn > 0 ? WideCharToMultiByte(SalZipPwdResolveCP(oemCodePage), 0, w, wn, out, outSize - 1, NULL, NULL) : 0;
    SecureZeroMemory(w, sizeof(w));
    if (n <= 0)
    {
        out[0] = 0;
        return -1;
    }
    out[n] = 0;
    return (int)strlen(out);
}

// The form a new or updated archive is keyed with (contract Z3): 'acp' when
// representable, otherwise 'utf8'; for a self-extracting archive the old
// read, which is what the stub's own prompt will produce. Returns the length
// or -1.
inline int SalZipPwdPackForm(const wchar_t* typed, char* out, int outSize, BOOL selfExtractor,
                             UINT codePage = CP_ACP)
{
    if (selfExtractor)
        return SalZipPwdOldRead(typed, out, outSize, codePage);
    int n = SalZipPwdAcp(typed, out, outSize, codePage);
    if (n < 0)
        n = SalZipPwdUtf8(typed, out, outSize);
    return n;
}

inline void SalZipPwdAddForm(CSalZipPwdCandidates* c, int kind, const char* bytes, int len)
{
    if (len < 0 || len >= SALZIPPWD_FORM_BUF || c->Count >= SALZIPPWD_FORMS)
        return;
    for (int i = 0; i < c->Count; i++)
        if (c->Forms[i].Len == len && memcmp(c->Forms[i].Bytes, bytes, len) == 0)
            return; // each distinct byte string once
    CSalZipPwdForm* f = &c->Forms[c->Count++];
    f->Kind = kind;
    f->Len = len;
    memcpy(f->Bytes, bytes, len);
    f->Bytes[len] = 0;
}

// The ordered candidates for unpacking, testing and viewing (contract Z4).
// An ASCII text gives exactly one.
inline void SalZipPwdCandidates(const wchar_t* typed, CSalZipPwdCandidates* c,
                                UINT codePage = CP_ACP, UINT oemCodePage = CP_OEMCP)
{
    if (c == NULL)
        return;
    SecureZeroMemory(c, sizeof(*c));
    char buf[SALZIPPWD_FORM_BUF];
    char oem[SALZIPPWD_FORM_BUF];
    int n = SalZipPwdAcp(typed, buf, sizeof(buf), codePage);
    if (n >= 0)
    {
        SalZipPwdAddForm(c, SALZIPPWD_ACP, buf, n);
        int on = SalZipPwdOem(buf, n, oem, sizeof(oem), codePage, oemCodePage);
        if (on >= 0)
            SalZipPwdAddForm(c, SALZIPPWD_OEM, oem, on);
    }
    n = SalZipPwdUtf8(typed, buf, sizeof(buf));
    if (n >= 0)
        SalZipPwdAddForm(c, SALZIPPWD_UTF8, buf, n);
    n = SalZipPwdOldRead(typed, buf, sizeof(buf), codePage);
    if (n >= 0)
        SalZipPwdAddForm(c, SALZIPPWD_OLDREAD, buf, n);
    SecureZeroMemory(buf, sizeof(buf));
    SecureZeroMemory(oem, sizeof(oem));
}
