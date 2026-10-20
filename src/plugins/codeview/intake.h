// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// intake.h - everything the host decides about a file BEFORE the page sees it:
// is it text, in what encoding, what language, and which rendering band
// (spec FR-005/006, FR-024, FR-026/027; contracts/claimed-types.md S5).

#pragma once

#include <string>
#include <vector>

enum CvEncoding
{
    cvEncUtf8,     // valid UTF-8, no BOM
    cvEncUtf8Bom,
    cvEncUtf16LE,
    cvEncUtf16BE,
    cvEncAnsi,     // a single-byte code page (the system one, or a chosen table)
};

enum CvEol
{
    cvEolNone,
    cvEolCRLF,
    cvEolLF,
    cvEolCR,
    cvEolMixed,
};

enum CvBand
{
    cvBandHighlight, // full syntax highlighting
    cvBandPlainSize, // plain text: over the highlighting size limit
    cvBandPlainLine, // plain text: a line over the length limit
    cvBandDeclined,  // not ours: binary, too large, or unreadable
};

struct CvIntake
{
    CvBand Band = cvBandDeclined;
    CvEncoding Encoding = cvEncUtf8;
    CvEol Eol = cvEolNone;
    int Language = -1;      // index into CvLanguages, or -1 = unidentified
    BOOL LanguageForced = FALSE;
    int InvalidBytes = 0;   // sequences replaced with U+FFFD (spec FR-024)
    BOOL TableApplied = FALSE; // a conversion table was applied to single-byte bytes (feature 262)
    BOOL IoError = FALSE;   // could not be opened/read (vs. "declined: not text")
    __int64 FileSize = 0;
    int LineCount = 0;
    int LongestLine = 0;
    BOOL TrailingNewline = TRUE;
    std::string Utf8;       // the decoded text, UTF-8, LF-separated (what /text serves)
};

// Cheap pre-open classification: reads at most the first 8 KB and never the
// whole file (spec FR-027 -- must stay imperceptible even on a 2 GB file).
// Returns FALSE when the plugin must decline so the built-in viewer opens it.
BOOL CvCanView(const char* nameUtf8);

// Full intake: read, decode, classify, identify. 'forcedEncoding' < 0 means
// detect; 'forcedLanguage' < 0 means identify. 'ansiTable' (256 bytes from
// EnumConversionTables, or NULL) is applied to the bytes when the result is
// cvEncAnsi - then read in the system code page, as the built-in viewer shows
// them (feature 262); NULL keeps the system code page alone.
BOOL CvLoadFile(const char* nameUtf8, int forcedEncoding, const char* ansiTable, int forcedLanguage, CvIntake& out);

// Language identification from the name alone, then from content when the name
// is silent or ambiguous (spec FR-005/006). 'head' may be empty.
int CvIdentifyLanguage(const char* nameUtf8, const char* head, size_t headLen);
