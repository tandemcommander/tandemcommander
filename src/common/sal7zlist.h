// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// sal7zlist.h
//
// Parser of the 7-Zip "technical" listing (feature 084-archiver-cleanup,
// contract specs/084-archiver-cleanup/contracts/7z-slt-listing.md).
//
// The input is the complete stdout of the BARE technical listing
//     7z l -slt -ba -sccUTF-8 -scsUTF-8 -- "<archive>"
// i.e. one "Key = Value" block per archive item, blocks separated by blank
// lines, nothing else. "-ba" matters: without it 7-Zip prints a preamble and
// the archive's own properties first, and a multi-line ARCHIVE COMMENT is
// printed there verbatim - a comment containing a line of ten '-' followed by
// "Path = ..." lines would inject entries into the listing (independent
// review of feature 084, finding 2). Item comments are flattened by 7-Zip onto
// one line and are harmless. The parser is pure (no I/O, no allocation) so
// that saltests can cover it; the caller turns the items into panel entries.
//

// one archive item; Path points INTO the parsed text and is not terminated
struct CSal7zListItem
{
    const char* Path; // UTF-8, separators as 7-Zip wrote them ('\' or '/')
    int PathLen;      // bytes, > 0
    BOOL IsDir;       // "Folder = +" or 'D' in Attributes
    unsigned __int64 Size;
    BOOL HasPackedSize; // FALSE when "Packed Size =" is empty (solid block member)
    unsigned __int64 PackedSize;
    BOOL HasDate;        // FALSE when "Modified" is absent or malformed
    SYSTEMTIME Modified; // local time as 7-Zip prints it, milliseconds dropped
    DWORD Attributes;    // FILE_ATTRIBUTE_READONLY/HIDDEN/SYSTEM/ARCHIVE from the letters
    BOOL Encrypted;      // "Encrypted = +"
};

// called for every item in listing order; return FALSE to stop (the parser
// then returns SAL7Z_STOPPED)
typedef BOOL (*FSal7zListItem)(const CSal7zListItem* item, void* ctx);

#define SAL7Z_OK 0            // all items delivered (none for an empty archive)
#define SAL7Z_NOT_BARE 1      // a "----------" line: not the bare (-ba) listing - refused,
                              // the text before it could come from an archive comment
#define SAL7Z_NO_PATH 2       // an item block without "Path ="
#define SAL7Z_BAD_SIZE 3      // "Size =" is not a decimal number
#define SAL7Z_UNSAFE_PATH 4   // empty, absolute, or containing a ".." component
#define SAL7Z_STOPPED 5       // the callback returned FALSE

// parses 'text' (UTF-8, 'len' bytes, need not be terminated, LF or CRLF line
// ends); on an error 'errorLine' (if not NULL) receives the 1-based line
// number where it was detected
int SalParse7zTechList(const char* text, size_t len, FSal7zListItem callback, void* ctx,
                       int* errorLine);

// TRUE when the item path is safe to present: not empty, not absolute (no
// leading separator, no drive "X:"), no ".." component; separators '\' and '/'
BOOL SalIs7zPathSafe(const char* path, int len);
