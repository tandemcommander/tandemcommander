// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Feature 428: the identity ("scope") of one copy of the program - the folder it runs from.
//
// Header-only and free of the C runtime: the core's settings store (portstore.cpp, through
// salportable.h), saltests and fcremote.exe (a CRT-free helper of the File Comparator that has to
// find "its" program) compute it by this one rule. The scope is 16 lower-case hex digits of
// FNV-1a 64 over the folder's volume serial number and file ID: the same folder reached through
// any path (a subst drive, a mount point, another case) gives the same scope, two folders give
// different ones. See specs/428-portable-build/research.md (R-04).

#pragma once

#include <windows.h>

inline unsigned __int64 SalPortableFnv1a64(const unsigned char* data, int size)
{
    unsigned __int64 h = 14695981039346656037ULL;
    for (int i = 0; i < size; i++)
    {
        h ^= data[i];
        h *= 1099511628211ULL;
    }
    return h;
}

// 'fileId16' = the 16 bytes of FILE_ID_128; 'out' gets 16 lower-case hex digits + the terminator
inline void SalPortableScopeHex(unsigned __int64 volumeSerial, const unsigned char* fileId16, char* out)
{
    unsigned char bytes[24];
    for (int i = 0; i < 8; i++)
        bytes[i] = (unsigned char)((volumeSerial >> (8 * i)) & 0xFF); // masked: Debug /RTCc stops a lossy cast
    for (int i = 0; i < 16; i++)
        bytes[8 + i] = fileId16[i];
    unsigned __int64 h = SalPortableFnv1a64(bytes, (int)sizeof(bytes));
    static const char hex[] = "0123456789abcdef";
    for (int i = 15; i >= 0; i--)
    {
        out[i] = hex[h & 0xF];
        h >>= 4;
    }
    out[16] = 0;
}

// the scope of the folder 'dir' (wide; "E:\" for a drive root); 'out' as above. The identity comes
// from FileIdInfo, else from the volume serial + file index, else (no identity at all) from the
// path itself, upper-cased - so the result is never empty.
inline void SalPortableFolderScope(const WCHAR* dir, char* out)
{
    unsigned __int64 serial = 0;
    unsigned char id16[16];
    for (int i = 0; i < 16; i++)
        id16[i] = 0;
    BOOL ok = FALSE;
    HANDLE h = CreateFileW(dir, FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                           OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (h != INVALID_HANDLE_VALUE)
    {
        // FILE_ID_INFO / FileIdInfo (Windows 8+) - the headers stop at _WIN32_WINNT 0x0601 here
        struct
        {
            ULONGLONG VolumeSerialNumber;
            BYTE FileId[16];
        } fid;
        const int FILE_ID_INFO_CLASS = 18; // FileIdInfo
        if (GetFileInformationByHandleEx(h, (FILE_INFO_BY_HANDLE_CLASS)FILE_ID_INFO_CLASS, &fid, sizeof(fid)))
        {
            serial = fid.VolumeSerialNumber;
            for (int i = 0; i < 16; i++)
            {
                id16[i] = fid.FileId[i];
                if (id16[i] != 0)
                    ok = TRUE;
            }
        }
        if (!ok)
        {
            BY_HANDLE_FILE_INFORMATION bi;
            if (GetFileInformationByHandle(h, &bi))
            {
                serial = bi.dwVolumeSerialNumber;
                for (int i = 0; i < 4; i++)
                {
                    id16[i] = (unsigned char)((bi.nFileIndexLow >> (8 * i)) & 0xFF);
                    id16[4 + i] = (unsigned char)((bi.nFileIndexHigh >> (8 * i)) & 0xFF);
                }
                ok = TRUE;
            }
        }
        CloseHandle(h);
    }
    if (!ok) // no identity from the file system: the path, upper-cased, without a trailing backslash
    {
        WCHAR up[1024];
        int n = 0;
        while (dir[n] != 0 && n < 1023)
        {
            up[n] = dir[n];
            n++;
        }
        while (n > 2 && up[n - 1] == L'\\')
            n--;
        up[n] = 0;
        CharUpperBuffW(up, (DWORD)n);
        serial = SalPortableFnv1a64((const unsigned char*)up, n * (int)sizeof(WCHAR));
    }
    SalPortableScopeHex(serial, id16, out);
}

// the RCDATA resource that marks the portable edition's executable (salamand.rc2 under TC_PORTABLE);
// fcremote.exe looks for it in the program it belongs to
#define SALPORTABLE_EDITION_RESOURCE L"TC_PORTABLE_EDITION"
