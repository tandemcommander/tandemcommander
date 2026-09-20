// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// render.h - color schemes, encoding detection, GitHub slug, and syntax-
// highlight interface for mdview. Markdown -> HTML generation lives in
// htmlgen.h; the rendering surface is WebView2 (see webglue.h). The v1
// RTF/RichEdit path was retired in feature 021.

#pragma once

#include <windows.h>
#include <string>
#include <vector>

// --- Color scheme (data-model.md) -----------------------------------------

struct MdSyntax // 9 syntax token classes
{
    COLORREF kw, str, num, cmt, type, fn, op, add, del;
};

struct MdTheme
{
    const char* id;   // stable ASCII id (never localized, never an index)
    int nameStrId;    // IDS_THEME_FIRST + index (localized display name)
    bool dark;
    COLORREF docBg, body, heading, link, linkActive;
    COLORREF quoteText, quoteAccent, codeInlineFg, codeInlineBg;
    COLORREF codeBg, codeText, tableBorder, tableHeadBg, rule;
    COLORREF sel, selText, imgFg, imgBg;
    MdSyntax syn;
};

extern const MdTheme MdThemes[];
extern const int MdThemeCount;                 // == 10
const MdTheme* MdThemeById(const char* id);    // nullptr if unknown
const MdTheme* MdThemeDefault(bool dark);      // paper / graphite
int MdThemeIndex(const MdTheme* t);

// --- Encoding detection (research.md R10, FR-035) -------------------------

enum MdEncoding
{
    MDENC_UTF8,
    MDENC_UTF8BOM,
    MDENC_UTF16LE,
    MDENC_UTF16BE,
    MDENC_ANSI,   // legacy fallback (system code page) - show warning bar
    MDENC_BINARY  // not text - caller should hand off to the text/hex viewer
};

// Decodes raw bytes into UTF-16 'out'. Returns the detected encoding.
MdEncoding MdDetectDecode(const BYTE* data, size_t len, std::wstring& out);

// --- limits (FR-055) ------------------------------------------------------

struct MdRenderLimits
{
    size_t maxDepth = 64;                     // nesting cap
    size_t maxNodesText = 40u * 1024 * 1024;  // output byte cap
};

// GitHub-style heading slug (lowercase, keep letters/digits/-/_ then spaces
// -> '-'; Czech diacritics preserved). Exposed for testing and htmlgen.
std::wstring MdSlug(const std::wstring& headingText);

// --- syntax highlighting (highlight.cpp) ----------------------------------
// Stable token-class indices consumed by htmlgen's MDCF_*->CSS-class adapter.
#define MDCF_KEYWORD 15
#define MDCF_STRING  16
#define MDCF_NUMBER  17
#define MDCF_COMMENT 18
#define MDCF_TYPE    19
#define MDCF_FUNC    20
#define MDCF_OP      21

struct HlRun
{
    size_t start, len;
    int colorCf; // one of MDCF_*
};

// Best-effort lexical highlighting for the tier-1 languages (FR-005).
// Unknown/absent language => 'runs' left empty (plain block).
void HighlightCode(const std::wstring& code, const std::string& lang, std::vector<HlRun>& runs);
