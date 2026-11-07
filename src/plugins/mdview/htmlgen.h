// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// htmlgen.h - Markdown (UTF-8) -> self-contained HTML document + theme CSS.
// Engine-independent and pure (no I/O, no network). Parses with md4c and
// emits an inert, static document to be rendered by the locked-down WebView2
// surface (src/common/webhost/). Raw embedded HTML is passed through verbatim
// (feature 021 FR-020/FR-022); safety comes from the engine lockdown, not a
// sanitizer.

#pragma once

#include "render.h" // MdTheme, MdRenderLimits
#include <string>
#include <vector>

// A referenced image that the WebView2 interceptor must serve on demand.
struct MdImageRef
{
    enum Kind { Local, Remote } kind;
    std::wstring pathOrUrl; // Local: absolute \\?\-ready path; Remote: full URL
};

// Feature 408: the copy control of a code block (contracts/copy-address.md of
// specs/408-mdview-code-copy). 'base' is the address prefix the control of block n
// links to (base + n); empty = no controls (the document of before 408, byte for
// byte). The texts are UTF-8 and are escaped by the generator.
struct MdCopyUi
{
    std::string base;    // "https://mdview.invalid/tc-copy-<token>-<serial>/" or ""
    std::string label;   // the control's text ("Copy")
    std::string tooltip; // its title attribute
    std::string copied;  // the notice shown after a copy ("Copied")
};

// Every copy address starts with this; the viewer consumes the whole family, so a
// forged or stale one does nothing instead of reaching the other link rules.
#define MD_COPY_FAMILY L"https://mdview.invalid/tc-copy-"

struct MdHtmlResult
{
    std::string html;                  // full UTF-8 HTML document
    std::vector<MdImageRef> images;    // index n == https://mdview.invalid/img/<n>
    std::vector<std::string> codeBlocks; // feature 408: index n == the source of the control base + n (UTF-8, as md4c gives it)
    std::vector<std::wstring> anchors; // heading slugs (unique)
    int matchCount = 0;                // number of <mark id="mdfind-N"> emitted
    size_t bytesOut = 0;
};

// Feature 314: the width of the text column (View > Page Width). The value is
// also what the plugin stores (PageWidth, REG_DWORD), so the numbers never
// change. NORMAL is the page of before 314 and the default.
enum MdPageWidth
{
    MDPW_NORMAL = 0, // 46rem
    MDPW_WIDE = 1,   // 64rem
    MDPW_WIDER = 2,  // 90rem
    MDPW_FULL = 3,   // no limit (the page padding stays)
    MDPW_COUNT = 4
};

// A stored value as a level: 0..3 as is, anything else (corrupt, or written by
// a later version) -> MDPW_NORMAL.
int MdPageWidthFromStored(unsigned v);

// Renders 'mdUtf8' with 'theme' into 'out'. 'docDir' (UTF-16, may exceed
// MAX_PATH) is used only to classify/resolve image references. When
// 'findTerm' (UTF-16) is non-empty, case-insensitive matches in body text are
// wrapped in <mark id="mdfind-N"> (script-free find). When 'allowRemote' is
// true, remote images become servable <img> (consent granted); otherwise they
// render as inert placeholders. 'pageWidth' is an MdPageWidth (out of range ->
// NORMAL). 'copyUi' (feature 408), when given with a non-empty base, puts a copy
// control on every code block and fills out.codeBlocks. Never throws; bounded by
// 'lim'.
bool MdRenderHtml(const std::string& mdUtf8, const MdTheme& theme,
                  const std::wstring& docDir, MdHtmlResult& out,
                  const std::wstring& findTerm = L"", bool allowRemote = false,
                  int pageWidth = MDPW_NORMAL, const MdCopyUi* copyUi = nullptr,
                  const MdRenderLimits& lim = MdRenderLimits());

// Feature 408: the text a code block's control puts on the clipboard - the block's
// source (an entry of MdHtmlResult::codeBlocks) as UTF-16, without the line break
// that ends its last line, U+0000 shown as U+FFFD (what the page shows), and every
// LF not preceded by CR as CR LF (the Windows clipboard convention, as the Code
// Viewer copies).
std::wstring MdCodeClipboardText(const std::string& srcUtf8);

// Feature 408: classifies an activated address. MDCOPY_NONE: not in the
// MD_COPY_FAMILY (the other link rules apply). MDCOPY_REFUSED: in the family but
// not exactly 'base' followed by a canonical decimal (no sign, no leading zero
// unless "0", at most 9 digits) below 'count' - a forged, stale or damaged address;
// nothing must happen. MDCOPY_OK: *index is set. An empty 'base' refuses every
// address of the family.
enum MdCopyLink
{
    MDCOPY_NONE = 0,
    MDCOPY_REFUSED = 1,
    MDCOPY_OK = 2
};
MdCopyLink MdParseCopyLink(const std::wstring& uri, const std::wstring& base, size_t count, size_t* index);

// Generates the inline stylesheet (CSS variables from the theme + base rules:
// body inset, reading measure, tables, code, blockquote, images, marks).
std::string MdBuildThemeCss(const MdTheme& theme);

// Renders the raw source text 'srcUtf8' as an inert, escaped <pre> document
// (the "View Source" / Open-as-Text mode). No Markdown parsing; 'findTerm'
// wraps matches in <mark id="mdfind-N"> exactly like MdRenderHtml so find works
// identically on the source; 'pageWidth' as for MdRenderHtml. Never throws.
bool MdBuildSourceHtml(const std::string& srcUtf8, const MdTheme& theme,
                       MdHtmlResult& out, const std::wstring& findTerm = L"",
                       int pageWidth = MDPW_NORMAL);
