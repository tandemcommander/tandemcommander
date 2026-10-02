// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salheapstr.h
//
// A heap string of exactly the needed size, for texts built from a path that
// may be as long as the program supports (SAL_MAX_PATH_UTF8 bytes, or several
// such parts joined). Feature 095: the disk-cache name of an archive in a panel
// and the messages naming that archive were built in stack buffers of 260-830
// bytes with unbounded copies.
//
// Header-only and pure (the byte table is a parameter), so it is covered by
// saltests. It does NOT replace the exported StrICpy.
//
//*****************************************************************************

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

class CSalHeapString
{
public:
    CSalHeapString() : Buf(NULL), BufSize(0) {}
    ~CSalHeapString() { free(Buf); }

    // Allocates strlen(src) + 1 + reserve bytes and copies 'src' into them. With
    // 'byteTable' (256 entries) every byte is mapped through it - with the core's
    // LowerCase table the result is byte for byte what StrICpy(dest, src) writes.
    // 'reserve' is the room left for what the caller appends. Returns FALSE when
    // memory is low (the string is then empty and Size() is 0).
    bool Copy(const char* src, size_t reserve = 0, const unsigned char* byteTable = NULL)
    {
        Free();
        if (src == NULL)
            return false;
        size_t len = strlen(src);
        if (reserve > (size_t)0x7FFFFFF0 || len > (size_t)0x7FFFFFF0 - reserve) // Size() is an int
            return false;
        Buf = (char*)malloc(len + 1 + reserve);
        if (Buf == NULL)
            return false;
        BufSize = len + 1 + reserve;
        if (byteTable == NULL)
            memcpy(Buf, src, len);
        else
        {
            for (size_t i = 0; i < len; i++)
                Buf[i] = (char)byteTable[(unsigned char)src[i]];
        }
        Buf[len] = 0;
        return true;
    }

    // printf into a buffer of exactly the needed size. Returns FALSE on a format
    // error or low memory (the string is then empty).
    bool Printf(const char* format, ...)
    {
        Free();
        if (format == NULL)
            return false;
        va_list args;
        va_start(args, format);
        int len = _vscprintf(format, args);
        va_end(args);
        if (len < 0)
            return false;
        Buf = (char*)malloc((size_t)len + 1);
        if (Buf == NULL)
            return false;
        BufSize = (size_t)len + 1;
        va_start(args, format);
        int written = vsnprintf(Buf, BufSize, format, args);
        va_end(args);
        if (written != len)
        {
            Free();
            return false;
        }
        return true;
    }

    // the writable buffer; NULL when nothing is allocated
    char* Get() { return Buf; }
    // the text, never NULL ("" when nothing is allocated) - for read-only consumers
    const char* Text() const { return Buf != NULL ? Buf : ""; }
    // the buffer size in bytes, terminator and reserve included (0 when nothing is allocated)
    int Size() const { return (int)BufSize; }

    void Free()
    {
        free(Buf);
        Buf = NULL;
        BufSize = 0;
    }

private:
    char* Buf;
    size_t BufSize;
    CSalHeapString(const CSalHeapString&);            // not copyable
    CSalHeapString& operator=(const CSalHeapString&); // not copyable
};
