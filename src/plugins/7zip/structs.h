// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "Common/MyString.h"
#include "Common/StringConvert.h"

// Plugin interface 104: every char* name/path crossing the Salamander
// interface is UTF-8, while 7za works with UTF-16 (UString/BSTR). Use these
// two helpers at that boundary - 7za's GetUnicodeString()/GetAnsiString()
// default to CP_ACP and would mangle (or drop) any non-ASCII name.
inline UString U8ToUString(const char* u8) { return MultiByteToUnicodeString(u8, CP_UTF8); }
inline AString UStringToU8(const UString& s) { return UnicodeStringToMultiByte(s, CP_UTF8); }

// feature 087: empties a string that held a password. SecureZeroMemory over the
// text cannot be optimised away; Wipe_and_Empty then clears the rest of the buffer.
inline void WipeUString(UString& s)
{
    if (s.Len() != 0)
        SecureZeroMemory(s.GetBuf(), s.Len() * sizeof(wchar_t));
    s.Wipe_and_Empty();
}

struct CUpdateInfo
{
    bool NewData;
    bool NewProperties;

    bool ExistsInArchive;
    int ArchiveItemIndex;

    bool ExistsOnDisk;
    int FileItemIndex;
    bool IsAnti;
};

// used in updatecallback
struct CFileItem
{
    UINT32 Attributes;
    FILETIME CreationTime;
    FILETIME LastAccessTime;
    FILETIME LastWriteTime;
    UINT64 Size;
    UString Name;
    UString FullPath;
    bool IsDir;

    BOOL CanDelete; // TRUE if Overwrite was chosen when updating the archive, otherwise FALSE

    // 'sourcePath', 'archiveRoot' and 'name' are UTF-8 strings from the interface
    CFileItem(const char* sourcePath, const char* archiveRoot, const char* name, DWORD attr, UINT64 size, FILETIME lastWrite, bool isDir)
    {
        // if archiveRoot is empty, the name must not start with a backslash '\'
        if (strlen(archiveRoot) > 0)
            Name = U8ToUString(archiveRoot) + UString(L"\\") + U8ToUString(name);
        else
            Name = U8ToUString(name);

        FullPath = U8ToUString(sourcePath) + UString(L"\\") + U8ToUString(name);
        Attributes = attr;
        Size = size;
        LastWriteTime = CreationTime = LastAccessTime = lastWrite;
        IsDir = isDir;

        CanDelete = FALSE;
    }
};

// used in extractcallback
struct CArchiveItem
{
    UString NameInArchive; // in the archive (i.e. including the path)
    UString Name;
    DWORD Attr;
    FILETIME LastWrite;
    UINT64 Size;
    bool IsDir;
    UINT32 Idx;

    CArchiveItem(UINT32 idx, UString name, UINT64 size, DWORD attr, FILETIME lastWrite, bool isDir)
    {
        Idx = idx;
        //    NameInArchive = nameInArchive;
        Name = name;
        Size = size;
        Attr = attr;
        LastWrite = lastWrite;
        IsDir = isDir;
    }
};
