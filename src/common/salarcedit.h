// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salarcedit.h
//
// Feature 108: the identity of a file opened for editing from an archive
// (CFileTimeStamps, salamdr3.cpp). The member is extracted into a temporary
// copy in the disk cache; that copy is what the editor changes and what is
// packed back when the archive is left, so "the same edited file" means "the
// same temporary copy on disk": its folder and its name, compared by the file
// system's rule (feature 092, contracts/name-identity.md) - not by the code
// page's byte fold, which made "ĥ.txt" and "Ĺ.txt" one item (their
// UTF-8 bytes C4 A5 / C4 B9 fold together on CP1250) and dropped the second
// edit, whose temporary copy the disk cache then deleted under the editor.
//
// Header-only and pure apart from the 092 helpers, so it is covered by
// saltests.
//
//*****************************************************************************

#include "salunicode.h"

// TRUE when the two temporary copies are one file on disk: the folders are the
// same path and the names the same name by the file system's rule. The disk
// cache never places two different members in one folder under names that are
// equal by that rule (CCacheDirData::ContainTmpName), so two members are never
// one copy, and one member opened twice is.
inline BOOL SalEditedCopyIsSame(const char* sourcePath1, const char* fileName1,
                                const char* sourcePath2, const char* fileName2)
{
    return SalPathEqualOrdinalCI(sourcePath1, sourcePath2) &&
           SalNameEqualOrdinalCI(fileName1, -1, fileName2, -1);
}

// TRUE when two edited copies are packed back by one call of the packer: they
// go to the same folder inside the archive - compared byte for byte, the
// packer writes the folder exactly as it is given ("test\A.txt" and
// "Test.txt" must not be packed together) - and they lie in one folder on
// disk (the file system's rule).
inline BOOL SalEditedCopiesPackTogether(const char* zipRoot1, const char* sourcePath1,
                                        const char* zipRoot2, const char* sourcePath2)
{
    return strcmp(zipRoot1, zipRoot2) == 0 && SalPathEqualOrdinalCI(sourcePath1, sourcePath2);
}

// The panel keeps a path inside an archive as it was typed ("arc.zip\DIR") while the archive's
// listing found the folder by its own rule and stores it as "Dir"; an edited member is identified by
// the stored spelling (GetZIPPathAsStored108, fileswn6.cpp), so one member is one temporary copy
// whichever spelling led to it. TRUE when the stored folder name replaces the typed component: the
// two are the same name by the file system's rule and of the same byte length (replaced in place).
// A folder the listing matched only through the code-page byte fold ("Ĺ" for a typed "ĥ" - two
// folders the listing merges) keeps the typed spelling.
inline BOOL SalArcTakeStoredSpelling(const char* stored, int storedLen, const char* typed, int typedLen)
{
    return storedLen == typedLen && SalNameEqualOrdinalCI(stored, storedLen, typed, typedLen);
}
