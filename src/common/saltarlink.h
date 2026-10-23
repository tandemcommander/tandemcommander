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
// they stand for) and an extraction asked for one whose target it neither wrote nor was
// asked for takes the target's data from another pass over the archive - a tar link always
// names an earlier member, so the single forward pass has passed the data by then.
//
//*****************************************************************************

#define SAL_TAR_LINK_DEFER 4 // a hard link whose target's data this pass cannot give: a second pass

// what an extraction does with a link member it was asked to extract (feature 325):
// 'targetWritten' - the file the link names was written by this operation; 'targetDeferred' - that
// name is now a link deferred by this operation (its latest definition - it wins over data written
// under the name earlier, review 2: "a.txt" written, then redefined as a link to "z.txt", then a link
// to "a.txt" stands for z.txt's data, not for the "a.txt" on disk); 'targetAsked' - that name was
// asked for too; 'linkHasDotDot' - the link name has a ".." component (never matched, feature 309)
inline int SalTarLinkDecideAsked(char typeFlag, bool targetWritten, bool targetDeferred, bool targetAsked,
                                 bool linkHasDotDot)
{
    if (typeFlag == SAL_TAR_TYPE_HARDLINK)
    {
        if (linkHasDotDot)
            return SAL_TAR_LINK_REPORT_MISSING;
        if (targetDeferred)
            return SAL_TAR_LINK_DEFER;
        if (targetWritten)
            return SAL_TAR_LINK_COPY;
        // the target was asked for but not written (Skip, a refused name): reported as before (309)
        return !targetAsked ? SAL_TAR_LINK_DEFER : SAL_TAR_LINK_REPORT_MISSING;
    }
    if (typeFlag == SAL_TAR_TYPE_SYMLINK)
        return SAL_TAR_LINK_REPORT_UNSUPPORTED;
    return SAL_TAR_LINK_NONE;
}

// the data member a hard link stands for: the 'Ordinal'-th data member named 'DataName' in the archive
// (1 = the first); !Valid = none (no earlier member of that name holds data)
struct CSalTarLinkTarget
{
    std::string DataName;
    unsigned Ordinal = 0;
    unsigned __int64 Size = 0;
    bool Valid = false;
};

// resolves hard links as tar extracts them (review 1 of feature 325): a link names the file that exists
// under that name when the link is read - the LATEST earlier member of the name, which may be a data
// member (an archive updated by "tar -u" / "tar -r" stores a name again), another hard link (a chain:
// it stands for what that link stood for), or anything else (a folder, a symbolic link: no data).
// Feed every member in archive order; each call is O(1), so no chain is walked again. Out of memory
// leaves the resolver "broken": every later link is unresolved (reported - never resolved to an older
// member by a lost update)
class CSalTarLinkResolver
{
public:
    // a member carrying data (a regular file)
    void AddData(const char* name, unsigned __int64 size)
    {
        if (Broken)
            return;
        try
        {
            unsigned ordinal = ++Count[name];
            CSalTarLinkTarget& t = Latest[name];
            t.DataName = name;
            t.Ordinal = ordinal;
            t.Size = size;
            t.Valid = true;
        }
        catch (...)
        {
            Broken = true;
        }
    }
    // any other member (a folder, a symbolic link, a device ...): its name no longer holds data
    void AddOther(const char* name)
    {
        if (Broken)
            return;
        try
        {
            Latest[name] = CSalTarLinkTarget();
        }
        catch (...)
        {
            Broken = true;
        }
    }
    // a hard link 'name' -> 'linkName': what it stands for (also recorded as the latest of 'name')
    CSalTarLinkTarget AddLink(const char* name, const char* linkName)
    {
        CSalTarLinkTarget t;
        if (Broken)
            return t;
        try
        {
            std::unordered_map<std::string, CSalTarLinkTarget>::const_iterator it = Latest.find(std::string(linkName));
            if (it != Latest.end())
                t = it->second;
            Latest[name] = t;
        }
        catch (...)
        {
            Broken = true;
            return CSalTarLinkTarget();
        }
        return t;
    }
    bool IsBroken() const { return Broken; }

private:
    std::unordered_map<std::string, CSalTarLinkTarget> Latest; // name -> what it holds now
    std::unordered_map<std::string, unsigned> Count;           // name -> data members of it so far
    bool Broken = false;
};
