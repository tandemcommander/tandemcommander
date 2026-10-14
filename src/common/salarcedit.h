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
// "Test\b.txt" must not be packed together) - and they lie in one folder on
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

// Feature 153: the Archive Update dialog marks a file whose member another program changed in the
// archive since the file was opened for editing (F4) - "Update" then replaces that change. The
// member's size and time as listed at the F4 and the archive file's own time and size at the F4
// are kept with the edited copy (CFileTimeStampsItem); at the update the archive file is looked at
// again and, only when it changed, listed again to compare the member.

// TRUE when the archive file may have changed since the F4: either stamp is not known, or its time
// or size differs. FALSE (the archive is the file it was) needs no new listing.
inline BOOL SalArchiveChangedSinceEdit(BOOL editKnown, unsigned __int64 editTime, unsigned __int64 editSize,
                                       BOOL nowKnown, unsigned __int64 nowTime, unsigned __int64 nowSize)
{
    return !editKnown || !nowKnown || editTime != nowTime || editSize != nowSize;
}

// Where the edited member stands in the archive's listing now.
enum CSalEditedMemberNow
{
    semnUnknown, // no listing, or no single member answers to the name
    semnMissing, // the folder holds no member of that name
    semnListed,  // one member: its size and time are compared
};

// The member is looked up in its folder of the new listing by its exact name first, then by the file
// system's rule (the F4 refused a name with a twin by that rule, so one is expected): 'exact' and
// 'byRule' are the numbers of members found each way. Two candidates are not guessed between.
inline CSalEditedMemberNow SalEditedMemberFound(int exact, int byRule)
{
    if (exact == 1)
        return semnListed;
    if (exact == 0 && byRule == 1)
        return semnListed;
    if (exact == 0 && byRule == 0)
        return semnMissing;
    return semnUnknown;
}

// TRUE = mark the file: the member was removed, changed (size or time differ from the F4's listing),
// or cannot be told apart (fail closed - the mark only warns, nothing is withheld).
inline BOOL SalEditedMemberChangedInArchive(CSalEditedMemberNow now,
                                            unsigned __int64 editTime, unsigned __int64 editSize,
                                            unsigned __int64 nowTime, unsigned __int64 nowSize)
{
    if (now != semnListed)
        return TRUE;
    return editTime != nowTime || editSize != nowSize;
}
