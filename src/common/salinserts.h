// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// Numbered inserts of a message template (feature 127)
//
// The templates of the archivers' messages ("Unable to start the archiver "%1".
// The error was: %2") were expanded by FormatMessage, an A call that reads the
// bytes in the code page - while the inserts are names, paths and system error
// texts in UTF-8. This is the same expansion on bytes, so a UTF-8 template and
// UTF-8 inserts give a UTF-8 text.
//
// Understood: "%1" .. "%9" (a string insert), "%%" (a percent sign), "%n" (a
// new line), as FormatMessage does; "%" before any other character gives that
// character; a lone "%" at the end is dropped. Format specifications
// ("%1!d!") are not supported - no template of the program has one.
//
// Header-only, no dependencies but the C runtime; checked by saltests.
//

#include <stdlib.h>
#include <string.h>

// The highest insert number the template uses (0 = none).
inline int SalInsertsCount(const char* tmpl)
{
    int count = 0;
    if (tmpl == NULL)
        return 0;
    for (const char* s = tmpl; *s != 0; s++)
    {
        if (*s == '%')
        {
            if (s[1] == 0)
                break;
            s++;
            if (*s >= '1' && *s <= '9' && *s - '0' > count)
                count = *s - '0';
        }
    }
    return count;
}

// Expands the template with 'count' inserts (inserts[0] is "%1"). A NULL insert and an insert
// number above 'count' give nothing. Returns a malloc'd text holding the WHOLE message (the
// caller frees it), NULL for a NULL template or when memory is low. With 'buf' == NULL only
// the size is computed - used internally.
inline size_t SalInsertsExpandTo(char* buf, const char* tmpl, const char* const* inserts, int count)
{
    size_t len = 0;
    for (const char* s = tmpl; *s != 0; s++)
    {
        if (*s == '%')
        {
            if (s[1] == 0)
                break;
            s++;
            if (*s >= '1' && *s <= '9')
            {
                int index = *s - '1';
                const char* ins = index < count && inserts != NULL ? inserts[index] : NULL;
                if (ins != NULL)
                {
                    size_t insLen = strlen(ins);
                    if (buf != NULL)
                        memcpy(buf + len, ins, insLen);
                    len += insLen;
                }
            }
            else
            {
                if (buf != NULL)
                    buf[len] = *s == 'n' ? '\n' : *s;
                len++;
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
    return len + 1; // with the terminator
}

inline char* SalInsertsExpandAlloc(const char* tmpl, const char* const* inserts, int count)
{
    if (tmpl == NULL)
        return NULL;
    char* buf = (char*)malloc(SalInsertsExpandTo(NULL, tmpl, inserts, count));
    if (buf != NULL)
        SalInsertsExpandTo(buf, tmpl, inserts, count);
    return buf;
}
