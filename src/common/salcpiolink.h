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
