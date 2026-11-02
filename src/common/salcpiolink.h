// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcpiolink.h
//
// Hard-linked files in a cpio archive (feature 310). Header-only, no globals;
// for the tar plug-in (which also reads cpio and the cpio payload of rpm) and
// saltests.
//
// The "new" (newc, 070701) and crc (070702) formats store a file with several
// names as one member per name, all with the same inode number and device and a
// link count above one; the file's data is stored with ONE of them (GNU cpio,
// rpm, libarchive, busybox and the kernel's gen_init_cpio: the last one), the
// others are stored with size 0. The tar plug-in wrote those names as empty
// files. Now an extraction groups the members by (device, inode): a name stored
// with size 0 waits for the group's data and is then written as a copy of it.
// The odc / binary formats repeat the data with every name - never grouped.
//
//*****************************************************************************

// the state of one group during one extraction
#define SAL_CPIO_GROUP_NONE 0    // no member of the group carried data yet
#define SAL_CPIO_GROUP_WRITTEN 1 // the data was written by this operation (copies come from there)
#define SAL_CPIO_GROUP_LOST 2    // the data passed and was not written (not asked, Skip, an error)

// what an extraction does with a member of a group
#define SAL_CPIO_LINK_SKIP 0              // not asked: nothing written (the data, if any, is read past)
#define SAL_CPIO_LINK_WRITE 1             // write the member's own data under its own name
#define SAL_CPIO_LINK_WRITE_FOR_WAITING 2 // not asked, but asked names wait: write its data under the first one
#define SAL_CPIO_LINK_WAIT 3              // asked, stored with size 0, data not seen yet: wait for it
#define SAL_CPIO_LINK_COPY 4              // asked, stored with size 0: copy the file written for the group
#define SAL_CPIO_LINK_REPORT 5            // asked, stored with size 0, the data was not written: report, fail

// is the member a name of a file that may have its data stored with another member? ('newcOrCrc': the
// archive is in the newc or crc format; 'mode': c_mode; 'nlink': c_nlink)
inline bool SalCpioIsLinkGroupMember(bool newcOrCrc, unsigned long mode, unsigned long nlink)
{
    return newcOrCrc && (mode & 0170000) == 0100000 && nlink > 1;
}

// does an extraction keep the member in its group? ('isDir': read as a folder; 'ignored': not
// extracted under its own name; 'unusableName': ignored only because its name cannot be used - a name
// no file system takes (feature 393) or one that normalizes to nothing, e.g. "." (feature 394). Such a
// member may carry the file's data: it stays in the group as not asked, so the group's other names
// get the data; any other ignored member stays out
inline bool SalCpioKeepsGroupMember(bool newcOrCrc, unsigned long mode, unsigned long nlink, bool isDir,
                                    bool ignored, bool unusableName)
{
    return !isDir && (!ignored || unusableName) && SalCpioIsLinkGroupMember(newcOrCrc, mode, nlink);
}

// the action for a member of a group: 'asked' - the operation was asked to extract it (mask /
// selection); 'hasData' - it carries data (size above 0); 'state' - SAL_CPIO_GROUP_*; 'anyWaiting' -
// asked names of the group wait for its data
inline int SalCpioLinkDecide(bool asked, bool hasData, int state, bool anyWaiting)
{
    if (hasData)
    {
        if (state == SAL_CPIO_GROUP_WRITTEN) // data stored once more: its own content, as before
            return asked ? SAL_CPIO_LINK_WRITE : SAL_CPIO_LINK_SKIP;
        if (asked)
            return SAL_CPIO_LINK_WRITE;
        return anyWaiting ? SAL_CPIO_LINK_WRITE_FOR_WAITING : SAL_CPIO_LINK_SKIP;
    }
    if (!asked)
        return SAL_CPIO_LINK_SKIP;
    if (state == SAL_CPIO_GROUP_WRITTEN)
        return SAL_CPIO_LINK_COPY;
    if (state == SAL_CPIO_GROUP_LOST)
        return SAL_CPIO_LINK_REPORT;
    return SAL_CPIO_LINK_WAIT;
}

// Feature 395: a regular file whose data is stored under a name that normalizes to nothing (".", "./",
// "") is never extracted under that name. When an extraction was asked for it (its raw name matches
// the operation's names - only a whole Unpack's mask can: it is never listed) and the data reaches no
// name the operation writes, the member is reported and the operation fails, so the archive is kept
// ("Delete archive after unpacking"). Also for tar (no grouping) and odc / binary cpio.
#define SAL_EMPTY_NAME_SILENT 0  // nothing to say: no data, not asked, or the data reached a name
#define SAL_EMPTY_NAME_REPORT 1  // report now and fail the operation
#define SAL_EMPTY_NAME_PENDING 2 // a group's data passed unwritten: report at the end unless a later
                                 // member of the group writes the data or reports its loss

// the decision for such a member: 'regularFile' / 'hasData' (size above 0) / 'asked' (raw name
// matched); 'groupMember' - it stays in a newc / crc hard-link group (SalCpioKeepsGroupMember);
// 'cpioAction' - SalCpioLinkDecide for it (as not asked), 'groupState' - the group's SAL_CPIO_GROUP_*
// before it (both ignored outside a group)
inline int SalEmptyNameDataDecide(bool regularFile, bool hasData, bool asked, bool groupMember, int cpioAction,
                                  int groupState)
{
    if (!regularFile || !hasData || !asked)
        return SAL_EMPTY_NAME_SILENT;
    if (!groupMember)
        return SAL_EMPTY_NAME_REPORT;
    if (cpioAction == SAL_CPIO_LINK_WRITE_FOR_WAITING || groupState == SAL_CPIO_GROUP_WRITTEN)
        return SAL_EMPTY_NAME_SILENT; // a waiting name gets the data / the data was written already
    return SAL_EMPTY_NAME_PENDING;
}

// does a later member of a group with a pending empty-name loss settle it? 'cpioAction' - the
// member's SalCpioLinkDecide: the file's data written under it (WRITE), copied to it (COPY), or the
// loss reported at it (REPORT - feature 394's "(2)" box; no second box)
inline bool SalEmptyNamePendingCleared(int cpioAction)
{
    return cpioAction == SAL_CPIO_LINK_WRITE || cpioAction == SAL_CPIO_LINK_COPY ||
           cpioAction == SAL_CPIO_LINK_REPORT;
}
