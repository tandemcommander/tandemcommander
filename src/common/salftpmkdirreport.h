// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salftpmkdirreport.h
//
// FTP client, upload listing cache: what a reported Create Directory does to
// the cached listing of each path component's parent (feature 323). Header-
// only, pure - the FTP plug-in includes it and saltests checks it.
//
// The upload asks the cache "does the target exist?" and trusts a ready
// listing without asking the server. A successful Create Directory of a path
// ("a/new", "/x/y/new") proves only that its last component was created - the
// server accepts "MKD .cfg/new" because ".cfg" exists. An earlier component the
// cached parent listing does not show is a folder the listing missed (a dot
// folder a plain LIST hides; "Docs" typed as "docs" on a case-insensitive
// server), not a new one: recording it as new and empty let an upload into it
// overwrite its files without the question (feature 302, review 2). Such a
// parent listing is no longer trusted; only the last component is recorded as
// a new, empty folder, as before.
//
//*****************************************************************************

#include <string.h>

// TRUE when the path component 'name' names a folder: not NULL, not empty and not "." or ".."
// (an empty component - "a//b" - and "." create nothing; ".." goes up).
inline bool SalFtpMkdirIsNamedComponent(const char* name)
{
    return name != NULL && name[0] != 0 && strcmp(name, ".") != 0 && strcmp(name, "..") != 0;
}

enum SalFtpMkdirAction
{
    sfmaNothing,          // the cached parent listing stays as it is
    sfmaRecordCreated,    // the existing handling of a created folder: added to the parent listing,
                          // an empty listing of the folder when the parent listing did not have it
    sfmaInvalidateParent, // the parent listing is no longer trusted (the next upload lists it again)
};

// What a reported Create Directory does at the cached listing of one named component's parent.
// 'unknownResult': the command's result is not known (the connection closed during it);
// 'isLastNamed': the component is the last named one of the typed path (the folder the command made);
// 'parentListsIt': the cached parent listing is complete (ready, or a newer listing already received)
// and holds the component's name - FALSE also when the listing is still being received.
inline SalFtpMkdirAction SalFtpMkdirComponentAction(bool unknownResult, bool isLastNamed, bool parentListsIt)
{
    if (unknownResult)
        return sfmaInvalidateParent;
    if (isLastNamed)
        return sfmaRecordCreated;
    return parentListsIt ? sfmaNothing : sfmaInvalidateParent;
}
