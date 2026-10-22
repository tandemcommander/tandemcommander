// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpupname.h
//
// FTP client, upload: "does the target folder already hold this name?" for a
// name that differs from a listed one only in case (feature 303). Header-only,
// pure - the FTP plug-in includes it and saltests checks it.
//
// The upload's listing cache compares names by the server path type's rule:
// byte for byte on Unix paths. Many servers that list Unix paths store files on
// a case-insensitive file system (FileZilla Server, other Windows-backed
// servers): an upload of "B.txt" into a folder holding "b.txt" was sent without
// the overwrite question and the server replaced its "b.txt". The plug-in
// cannot tell such a server from a case-sensitive one, so for the overwrite
// decision a listed name that is the same name under the file system's rule of
// feature 092 (SalNameOrderEqualCI, salnameorder.h: "C-caron.txt" and
// "c-caron.txt" are one name; NFC / NFD forms and look-alikes of ASCII letters
// stay apart) counts as existing. Path identity ("the same folder") is not
// affected.
//
//*****************************************************************************

#include "salnameorder.h"

// The lowest index i < 'count' whose name getName(i) is not byte-equal to 'name' but is the same
// name case ignored (SalNameOrderEqualCI); -1 when there is none, 'name' is NULL or 'count' <= 0.
// getName(i) returns a NUL-terminated name or NULL (skipped). Each name is looked at once; two
// names with different ASCII first letters are told apart without converting.
template <class GetName>
inline int SalFtpFindCaseOnlyName(int count, GetName getName, const char* name)
{
    if (name == NULL)
        return -1;
    for (int i = 0; i < count; i++)
    {
        const char* listed = getName(i);
        if (listed != NULL && strcmp(listed, name) != 0 && SalNameOrderEqualCI(listed, -1, name, -1))
            return i;
    }
    return -1;
}
