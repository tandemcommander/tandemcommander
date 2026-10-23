// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <string>
#include <unordered_map>

//*****************************************************************************
//
// saltarlink.h
//
// Link members of a tar archive (feature 309). Header-only, no globals; for the
// tar plug-in and saltests.
//
// GNU tar and Python's tarfile store a second name of a file (a hard link in the
// source tree) as a member of type '1' that names the first one; a symbolic link
// is type '2'. The tar plug-in skipped both and still reported success, so
// "Delete archive after unpacking" deleted the archive with the left-out names.
// Now an extraction reproduces a hard link as a copy of the file it names when
// that file was written in the same operation; any other link member it was asked
// for is reported and fails the operation (the archive is kept).
//
// The name a link refers to is compared with member names after the same
// normalization - SalTarNormalizeNameU8, the rule ReadArchiveHeader always used
// for member names ("./a.txt" and "a.txt" are one name). That rule resolves ".."
// wrongly ("x/../a.txt" becomes "x\a.txt" - legacy, member names too), so a link
// name with a ".." component is never normalized or matched: such a link is
// reported (SalTarPathHasDotDotU8), never copied from a guessed file.
//
//*****************************************************************************

#define SAL_TAR_LINK_NONE 0               // not a link member
#define SAL_TAR_LINK_COPY 1               // a hard link to a file written in this operation: copy it
#define SAL_TAR_LINK_REPORT_MISSING 2     // a hard link to a file not written in this operation
#define SAL_TAR_LINK_REPORT_UNSUPPORTED 3 // a symbolic link (never created)

// tar type flags of the two link kinds (the values of LNKTYPE / SYMTYPE in the tar plug-in)
#define SAL_TAR_TYPE_HARDLINK '1'
#define SAL_TAR_TYPE_SYMLINK '2'

// normalizes a path read from an archive: '/' and '\' become one '\', "." is dropped, ".." removes the
// previous component (never above the root), a leading separator is dropped; a trailing separator is
// kept (the caller reads it as "a folder"). 'dst' must hold strlen(src) + 1 bytes (the result is never
// longer). Moved unchanged from CArchive::ReadArchiveHeader (feature 309).
inline void SalTarNormalizeNameU8(const char* src, char* dst)
{
    char* const start = dst;
    while (*src != '\0')
    {
        switch (*src)
        {
        case '\\':
        case '/':
            // when we encounter a slash, copy it if it is not the first path character and we do not have one already
            if (dst > start && *(dst - 1) != '\\')
                *dst++ = '\\';
            src++;
            break;
        case '.':
            if (*(src + 1) == '.' && (*(src + 2) == '\\' || *(src + 2) == '/' || *(src + 2) == '\0'))
            {
                char* dstOld = dst;

                // two dots - drop one directory level when possible
                if (dst > start)
                    dst -= 2;
                while ((dst > start) && (*dst != '\\'))
                    dst--;
                // testAIX.tar from martin.pobitzer@gmx.at created on AIX starts with path "../../empty"
                if (dst < dstOld)
                {
                    dst++;
                }
                src += 2;
                break;
            }
            else if (*(src + 1) == '\\' || *(src + 1) == '/' || *(src + 1) == '\0')
            {
                // a single dot - simply ignore it
                src++;
                break;
            }
            // otherwise it is the start of the name; fall through to copying
        default:
            // copy characters until the next slash
            while (*src != '\0' && *src != '\\' && *src != '/')
                *dst++ = *src++;
            break;
        }
    }
    // terminate the destination string
    *dst = '\0';
}

// does the path have a ".." component ('/' and '\' both separate)? (review 1 of feature 309)
inline bool SalTarPathHasDotDotU8(const char* path)
{
    const char* s = path;
    while (*s != '\0')
    {
        const char* end = s;
        while (*end != '\0' && *end != '/' && *end != '\\')
            end++;
        if (end - s == 2 && s[0] == '.' && s[1] == '.')
            return true;
        s = *end != '\0' ? end + 1 : end;
    }
    return false;
}

// what an extraction does with a member of type 'typeFlag' that it was asked to extract;
// 'targetWritten': the file the link names was written by this operation
inline int SalTarLinkDecide(char typeFlag, bool targetWritten)
{
    if (typeFlag == SAL_TAR_TYPE_HARDLINK)
        return targetWritten ? SAL_TAR_LINK_COPY : SAL_TAR_LINK_REPORT_MISSING;
    if (typeFlag == SAL_TAR_TYPE_SYMLINK)
        return SAL_TAR_LINK_REPORT_UNSUPPORTED;
    return SAL_TAR_LINK_NONE;
}

//*****************************************************************************
//
// Feature 325: hard-link members are listed (as files, with the size of the data member
// they name) and an extraction asked for one whose target it neither wrote nor was asked
// for takes the target's data from a second pass over the archive - a tar link always
// names an earlier member, so the single forward pass has passed the data by then.
//
//*****************************************************************************

#define SAL_TAR_LINK_DEFER 4 // a hard link whose target's data this pass cannot give: a second pass

// what an extraction does with a link member it was asked to extract (feature 325):
// 'targetWritten' - the file the link names was written by this operation; 'targetDeferred' - that
// name is itself a link deferred by this operation; 'targetAsked' - that name was asked for too;
// 'linkHasDotDot' - the link name has a ".." component (never matched, feature 309)
inline int SalTarLinkDecideAsked(char typeFlag, bool targetWritten, bool targetDeferred, bool targetAsked,
                                 bool linkHasDotDot)
{
    if (typeFlag == SAL_TAR_TYPE_HARDLINK)
    {
        if (linkHasDotDot)
            return SAL_TAR_LINK_REPORT_MISSING;
        if (targetWritten)
            return SAL_TAR_LINK_COPY;
        // the target was asked for but not written (Skip, a refused name): reported as before (309)
        return targetDeferred || !targetAsked ? SAL_TAR_LINK_DEFER : SAL_TAR_LINK_REPORT_MISSING;
    }
    if (typeFlag == SAL_TAR_TYPE_SYMLINK)
        return SAL_TAR_LINK_REPORT_UNSUPPORTED;
    return SAL_TAR_LINK_NONE;
}

// follows a chain of hard links: 'links' maps the name of every hard-link member to the name it
// refers to. 'dataName' = the first name of the chain that is not a hard link (the member that
// should hold the data). false for a cycle (never ends) - nothing to extract.
inline bool SalTarResolveHardLink(const std::unordered_map<std::string, std::string>& links,
                                  const std::string& linkName, std::string& dataName)
{
    std::string name = linkName;
    for (size_t steps = 0; steps <= links.size(); steps++)
    {
        std::unordered_map<std::string, std::string>::const_iterator it = links.find(name);
        if (it == links.end())
        {
            dataName = name;
            return true;
        }
        name = it->second;
    }
    return false; // more steps than links: a cycle
}

// the size to list for a hard link referring to 'linkName': the size of the data member the chain
// ends in ('sizes': the data members listed so far), else 0 (no such member, a cycle)
inline unsigned __int64 SalTarListedLinkSize(const std::unordered_map<std::string, std::string>& links,
                                             const std::unordered_map<std::string, unsigned __int64>& sizes,
                                             const std::string& linkName)
{
    std::string dataName;
    if (!SalTarResolveHardLink(links, linkName, dataName))
        return 0;
    std::unordered_map<std::string, unsigned __int64>::const_iterator it = sizes.find(dataName);
    return it != sizes.end() ? it->second : 0;
}
