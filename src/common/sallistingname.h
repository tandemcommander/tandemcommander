// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// sallistingname.h
//
// Which names the panel listing takes (CSalamanderDirectory::AddFile / AddDir,
// src/zip.cpp). Header-only, no globals; saltests checks it.
//
// The panel formats every listed name into fixed buffers of SAL_FIND_NAME_U8
// (3 * MAX_PATH = 780) bytes - the column-width measuring, drawing, quick
// search, the info line. Feature 222 bounded the names to fit, but only for an
// entry added with a folder part; an entry with no folder part (path == NULL:
// every file-system plug-in, the root of an archive) skipped the bound, so a
// tar member of 300 CJK letters (904 bytes) overflowed the stack when the
// archive was opened (feature 321).
//
//   with a folder part   unchanged (feature 222): the folder part and a
//                        folder's name at most MAX_PATH - 5 bytes; a file's
//                        name longer than that only below SAL_FIND_NAME_U8
//                        bytes and at most 255 UTF-16 units
//   no folder part       a name below SAL_FIND_NAME_U8 bytes, file or folder -
//                        nothing else is refused: file-system plug-ins list
//                        names over 255 UTF-16 units (registry value names,
//                        FTP servers)
//
//*****************************************************************************

#include <stddef.h>

#include "salmaskname.h" // SalNameTooLongForFileSystemU8

// the panel's name buffers (SAL_FIND_NAME_U8, salfileio.h - the core checks they are equal)
#define SAL_LISTING_NAME_MAX_BYTES (3 * MAX_PATH)
// a folder part, and a folder's own name in a folder part (feature 222)
#define SAL_LISTING_PATH_MAX_BYTES (MAX_PATH - 5)

// a file 'name' ('nameLen' bytes) added under 'path' ('pathLen' bytes, or NULL = no folder part)
inline bool SalListingAcceptsFileU8(const char* path, size_t pathLen, const char* name, size_t nameLen)
{
    if (path == NULL)
        return nameLen < SAL_LISTING_NAME_MAX_BYTES;
    if (pathLen > SAL_LISTING_PATH_MAX_BYTES)
        return false;
    return nameLen <= SAL_LISTING_PATH_MAX_BYTES ||
           (nameLen < SAL_LISTING_NAME_MAX_BYTES && !SalNameTooLongForFileSystemU8(name));
}

// a folder named with 'nameLen' bytes added under 'path' ('pathLen' bytes, or NULL)
inline bool SalListingAcceptsDirU8(const char* path, size_t pathLen, size_t nameLen)
{
    if (path == NULL)
        return nameLen < SAL_LISTING_NAME_MAX_BYTES;
    return pathLen <= SAL_LISTING_PATH_MAX_BYTES && nameLen <= SAL_LISTING_PATH_MAX_BYTES;
}
