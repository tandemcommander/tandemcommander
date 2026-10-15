// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "TreeMap.FileData.CZFile.h"
#include "TreeMap.FileData.CZDirectory.h"

// feature 211: a name that does not fit 'buff' is NO name (0, empty) - a part that did not fit
// was skipped and the rest appended: a file of a long name got its FOLDER's path, a deep item
// another item's path, and the shell's menu (Delete ...) acted on that other item
size_t CZFile::GetFullName(TCHAR* buff, size_t size)
{
    BOOL ok = TRUE;
    size_t pos = this->GetNameAux(NULL, buff, size, &ok);
    if (!ok)
    {
        if (size > 0)
            buff[0] = TEXT('\0');
        return 0;
    }
    return pos;
}

size_t CZFile::GetRelativeName(CZDirectory* root, TCHAR* buff, size_t size)
{
    BOOL ok = TRUE;
    size_t pos = this->GetNameAux(root, buff, size, &ok);
    if (!ok)
    {
        if (size > 0)
            buff[0] = TEXT('\0');
        return 0;
    }
    return pos;
}

// 'root' NULL: the full name; otherwise the name relative to 'root' (empty for 'root' itself);
// *ok FALSE when a part does not fit 'size'
size_t CZFile::GetNameAux(CZDirectory* root, TCHAR* buff, size_t size, BOOL* ok)
{
    size_t pos = 0;
    if (root != NULL && this == root)
    {
        if (size > 0)
            buff[0] = TEXT('\0');
        return 0;
    }
    if (this->_parent)
    {
        pos = this->_parent->GetNameAux(root, buff, size, ok);
        if (!*ok)
            return 0;
    }
    if ((pos + this->_namelen + 1) < size) //pos = path + null terminator; total = path + ( '\\' + name length ) + null terminator < size
    {
        if (pos && buff[pos - 1] != TEXT('\\'))
        {
            buff[pos] = TEXT('\\');
            pos++;
        }
        _tcscpy(buff + pos, this->_name);
        pos += this->_namelen;
    }
    else
    {
        *ok = FALSE;
        return 0;
    }
    return pos;
}