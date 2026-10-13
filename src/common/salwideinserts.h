// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// Wide inserts of a UTF-8 message template (feature 129)
//
// The Registry Editor plug-in put registry names (UTF-16) into its messages
// and paths with "%ls" in a narrow printf. The C runtime converts such an
// insert with the "C" locale: the first letter above U+00FF fails the whole
// call (an empty text with the secure functions, a text cut at that letter
// with vsprintf). This is the expansion without a locale: the template is
// UTF-8 bytes, every "%ls" takes the next insert and gives its UTF-8 form.
//
// Understood: "%ls" (the next wide insert; a missing or NULL one gives
// nothing) and "%%" (a percent sign). Any other "%" sequence is copied as it
// is - templates with other format specifications do not go through here.
// An unpaired surrogate in an insert becomes U+FFFD (this is text to show).
//
// The result is always the whole text: the caller gets a malloc'd buffer of
// the needed size (and frees it), NULL for a NULL template or low memory.
//
// Header-only (the plug-ins cannot compile a .cpp from src\common); needs
// <windows.h>; checked by saltests.
//

#include <stdlib.h>
#include <string.h>

// TRUE when the template has at least one "%ls" (and so must go through here).
inline BOOL SalWideInsertsUsed(const char* tmpl)
{
    if (tmpl == NULL)
        return FALSE;
    for (const char* s = tmpl; *s != 0; s++)
    {
        if (*s == '%')
        {
            if (s[1] == '%')
                s++;
            else if (s[1] == 'l' && s[2] == 's')
                return TRUE;
        }
    }
    return FALSE;
}

// The number of "%ls" in the template.
inline int SalWideInsertsCount(const char* tmpl)
{
    int count = 0;
    if (tmpl == NULL)
        return 0;
    for (const char* s = tmpl; *s != 0; s++)
    {
        if (*s == '%')
        {
            if (s[1] == '%')
                s++;
            else if (s[1] == 'l' && s[2] == 's')
            {
                count++;
                s += 2;
            }
        }
    }
    return count;
}

// One pass: with 'buf' == NULL only the size (terminator included) is computed.
inline size_t SalWideInsertsExpandTo(char* buf, const char* tmpl, const WCHAR* const* inserts, int count)
{
    size_t len = 0;
    int next = 0;
    for (const char* s = tmpl; *s != 0; s++)
    {
        if (*s == '%' && s[1] == '%')
        {
            if (buf != NULL)
                buf[len] = '%';
            len++;
            s++;
        }
        else if (*s == '%' && s[1] == 'l' && s[2] == 's')
        {
            const WCHAR* ins = next < count && inserts != NULL ? inserts[next] : NULL;
            next++;
            s += 2;
            if (ins != NULL && ins[0] != 0)
            {
                // (without the terminator: the length is given)
                int units = (int)wcslen(ins);
                int bytes = WideCharToMultiByte(CP_UTF8, 0, ins, units, NULL, 0, NULL, NULL);
                if (bytes > 0)
                {
                    if (buf != NULL)
                        WideCharToMultiByte(CP_UTF8, 0, ins, units, buf + len, bytes, NULL, NULL);
                    len += bytes;
                }
            }
        }
        else
        {
            if (buf != NULL)
                buf[len] = *s;
            len++;
        }
    }
    if (buf != NULL)
        buf[len] = 0;
    return len + 1;
}

inline char* SalWideInsertsExpandAlloc(const char* tmpl, const WCHAR* const* inserts, int count)
{
    if (tmpl == NULL)
        return NULL;
    char* buf = (char*)malloc(SalWideInsertsExpandTo(NULL, tmpl, inserts, count));
    if (buf != NULL)
        SalWideInsertsExpandTo(buf, tmpl, inserts, count);
    return buf;
}

// A wide text in lower case as UTF-8, in a malloc'd buffer (NULL for NULL or low memory) - for
// keys of a case-insensitive lookup (the disk cache name of a viewed registry value). The case
// is folded on the wide text: a byte-wise lower-case table applied to UTF-8 changes
// continuation bytes and makes different letters equal ("\xC3\x8A" and "\xC3\x9A" on code
// page 1250).
inline char* SalWideLowerToU8Alloc(const WCHAR* text)
{
    if (text == NULL)
        return NULL;
    size_t units = wcslen(text);
    WCHAR* lower = (WCHAR*)malloc((units + 1) * sizeof(WCHAR));
    if (lower == NULL)
        return NULL;
    memcpy(lower, text, (units + 1) * sizeof(WCHAR));
    if (units > 0)
        CharLowerBuffW(lower, (DWORD)units);
    char* ret = NULL;
    int bytes = WideCharToMultiByte(CP_UTF8, 0, lower, -1, NULL, 0, NULL, NULL); // with the terminator
    if (bytes > 0)
    {
        ret = (char*)malloc(bytes);
        if (ret != NULL && WideCharToMultiByte(CP_UTF8, 0, lower, -1, ret, bytes, NULL, NULL) <= 0)
        {
            free(ret);
            ret = NULL;
        }
    }
    free(lower);
    return ret;
}
