// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

class CZipList : public CZipCommon
{
public:
    CZipList(const char* zipName, CSalamanderForOperationsAbstract* salamander) : CZipCommon(zipName, "", salamander, NULL)
    {
        Extract = true;
        CaseSensitive = FALSE;
    }
    int ListArchive(CSalamanderDirectoryAbstract* dir, BOOL& haveFiles);
    int List(CSalamanderDirectoryAbstract* dir, BOOL& haveFiles);

    // feature 271: the listing was declared case-sensitive (a Unix-made entry, or a folder holding
    // names that differ only in case) - the operations started from it compare names the same way
    BOOL CaseSensitive;
};
