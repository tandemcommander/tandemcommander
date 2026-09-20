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

struct MdHtmlResult
{
    std::string html;                  // full UTF-8 HTML document
    std::vector<MdImageRef> images;    // index n == https://mdview.invalid/img/<n>
    std::vector<std::wstring> anchors; // heading slugs (unique)
    int matchCount = 0;                // number of <mark id="mdfind-N"> emitted
    size_t bytesOut = 0;
};

// Renders 'mdUtf8' with 'theme' into 'out'. 'docDir' (UTF-16, may exceed
// MAX_PATH) is used only to classify/resolve image references. When
// 'findTerm' (UTF-16) is non-empty, case-insensitive matches in body text are
// wrapped in <mark id="mdfind-N"> (script-free find). When 'allowRemote' is
// true, remote images become servable <img> (consent granted); otherwise they
// render as inert placeholders. Never throws; bounded by 'lim'.
bool MdRenderHtml(const std::string& mdUtf8, const MdTheme& theme,
                  const std::wstring& docDir, MdHtmlResult& out,
                  const std::wstring& findTerm = L"", bool allowRemote = false,
                  const MdRenderLimits& lim = MdRenderLimits());

// Generates the inline stylesheet (CSS variables from the theme + base rules:
// body inset, reading measure, tables, code, blockquote, images, marks).
std::string MdBuildThemeCss(const MdTheme& theme);

// Renders the raw source text 'srcUtf8' as an inert, escaped <pre> document
// (the "View Source" / Open-as-Text mode). No Markdown parsing; 'findTerm'
// wraps matches in <mark id="mdfind-N"> exactly like MdRenderHtml so find works
// identically on the source. Never throws.
bool MdBuildSourceHtml(const std::string& srcUtf8, const MdTheme& theme,
                       MdHtmlResult& out, const std::wstring& findTerm = L"");
