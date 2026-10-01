// SPDX-FileCopyrightText: 2026 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Standalone unit test for the mdview Markdown->HTML generator (htmlgen.cpp +
// md4c). Engine-independent: exercises the pure transformation without
// WebView2. Build via specs/021-mdview-html-renderer/quickstart.md.
//
// Asserts structural properties of the generated HTML across the feature's
// user stories (tables/alignment, code+lang, slugs, raw-HTML pass-through,
// text escaping / XSS boundary, local image rewrite, remote-image block).

#include <windows.h>
#include <string>
#include <cstdio>
#include "render.h"
#include "htmlgen.h"

static int g_pass = 0, g_fail = 0;

static void Check(const char* name, bool cond)
{
    printf(cond ? "  [PASS] %s\n" : "  [FAIL] %s\n", name);
    if (cond) g_pass++; else g_fail++;
}

static bool Has(const std::string& hay, const char* needle)
{
    return hay.find(needle) != std::string::npos;
}

static std::string Gen(const std::string& md, const std::wstring& docDir = L"C:\\docs",
                       const std::wstring& find = L"", bool allowRemote = false,
                       MdHtmlResult* keep = nullptr)
{
    const MdTheme* t = MdThemeById("paper");
    MdHtmlResult local;
    MdHtmlResult& r = keep ? *keep : local;
    MdRenderHtml(md, *t, docDir, r, find, allowRemote);
    return r.html;
}

int main()
{
    // US1: GFM table with column alignment
    {
        std::string h = Gen("| A | B | C |\n|:--|:-:|--:|\n| 1 | 2 | 3 |\n");
        Check("table renders as grid", Has(h, "<table>") && Has(h, "<th"));
        Check("table left align", Has(h, "text-align:left"));
        Check("table center align", Has(h, "text-align:center"));
        Check("table right align", Has(h, "text-align:right"));
    }
    // US1: heading slug
    {
        std::string h = Gen("# Hello World\n");
        Check("heading has slug id", Has(h, "id=\"hello-world\""));
        Check("heading tag", Has(h, "<h1"));
    }
    // US1: fenced code block with language + highlight class hooks
    {
        std::string h = Gen("```c\nint x = 42;\n```\n");
        Check("code block emitted", Has(h, "<pre><code"));
        Check("code language class", Has(h, "language-c"));
    }
    // US1: lists + task list
    {
        std::string h = Gen("- a\n- b\n\n1. one\n2. two\n\n- [x] done\n- [ ] todo\n");
        Check("unordered list", Has(h, "<ul>"));
        Check("ordered list", Has(h, "<ol>"));
        Check("task checkbox", Has(h, "type=\"checkbox\"") && Has(h, "checked"));
    }
    // US2 / escaping: literal '<' in text must be escaped (XSS boundary)
    {
        std::string h = Gen("a < b and c > d & e\n");
        Check("text '<' escaped", Has(h, "&lt;"));
        Check("text '&' escaped", Has(h, "&amp;"));
    }
    // US4: embedded raw HTML rendered verbatim (safety is the engine lockdown)
    {
        std::string h = Gen("Press <kbd>Esc</kbd> to close.\n");
        Check("inline raw HTML passed through", Has(h, "<kbd>Esc</kbd>"));
    }
    // US4 + US2: a raw HTML <script> block is passed through verbatim by the
    // generator (NOT sanitized); inertness is enforced by the WebView2 lockdown.
    {
        std::string h = Gen("<script>window.x=1</script>\n");
        Check("raw <script> block passed through (inert at engine)", Has(h, "<script>window.x=1</script>"));
        // and it is NOT executed here (pure string) - documented design
    }
    // feature 085 (F3): a document cannot navigate by itself - the http-equiv
    // attribute of raw HTML is renamed, everything else stays verbatim
    {
        std::string h = Gen("<meta http-equiv=\"refresh\" content=\"1; url=https://example.com/\">\n\ntext\n");
        Check("085 block meta refresh neutralised", !Has(h, "http-equiv") && Has(h, "data-tc-equiv=\"refresh\""));
        Check("085 rest of the tag kept", Has(h, "content=\"1; url=https://example.com/\""));
        h = Gen("x <meta HTTP-EQUIV = 'Refresh' content='0;url=a.md'> y\n");
        Check("085 inline, case and spaces", !Has(h, "HTTP-EQUIV") && Has(h, "data-tc-equiv = 'Refresh'"));
        // review 2 (REJECT): the '=' on the next line, or after a form feed
        h = Gen("<div>\n<meta http-equiv\n=\"refresh\" content=\"1;url=https://tracker/\">\n</div>\n");
        Check("085 block, '=' on the next line", !Has(h, "http-equiv") && Has(h, "data-tc-equiv"));
        h = Gen("x <meta http-equiv\n=\"refresh\" content=\"1;url=https://x\"> y\n");
        Check("085 inline, '=' on the next line", !Has(h, "http-equiv") && Has(h, "data-tc-equiv"));
        h = Gen("<meta http-equiv\f=\"refresh\" content=\"1;url=https://x\">\n");
        Check("085 form feed before '='", !Has(h, "http-equiv") && Has(h, "data-tc-equiv"));
        // outside a block md4c does not take these as HTML (escaped, inert); inside
        // a <div> block they are raw, and a browser reads the attribute
        h = Gen("<div>\n<meta content=\"1;url=https://x\"http-equiv=refresh>\n<meta/http-equiv=refresh>\n</div>\n");
        Check("085 after a quote or '/' (raw in a block)", !Has(h, "http-equiv") && Has(h, "<meta/data-tc-equiv=refresh>"));
        h = Gen("<p>the http-equiv attribute</p>\n");
        Check("085 prose in raw HTML untouched", Has(h, "the http-equiv attribute"));
        h = Gen("The `http-equiv=refresh` trick, and http-equiv=\"refresh\" in text.\n");
        Check("085 Markdown text untouched", Has(h, "http-equiv=refresh") && !Has(h, "data-tc-equiv"));
    }
    // US3: local relative image is rewritten to the interceptor origin
    {
        MdHtmlResult r;
        std::string h = Gen("![alt](pic.png)\n", L"C:\\docs", L"", false, &r);
        Check("local image rewritten", Has(h, "https://mdview.invalid/img/0"));
        Check("local image recorded", r.images.size() == 1 && r.images[0].kind == MdImageRef::Local);
    }
    // US3: remote image blocked by default (placeholder, not fetched)
    {
        MdHtmlResult r;
        std::string h = Gen("![x](http://example.com/x.png)\n", L"C:\\docs", L"", false, &r);
        Check("remote image blocked -> placeholder", Has(h, "md-imgph"));
        Check("remote image not listed (no fetch)", r.images.empty());
        Check("remote image no <img src=http", !Has(h, "src=\"http://example.com"));
    }
    // US3: with consent, remote image becomes servable
    {
        MdHtmlResult r;
        std::string h = Gen("![x](http://example.com/x.png)\n", L"C:\\docs", L"", true, &r);
        Check("remote image with consent -> servable", Has(h, "https://mdview.invalid/img/0") &&
                                                            r.images.size() == 1 &&
                                                            r.images[0].kind == MdImageRef::Remote);
    }
    // US5: script-free find marks matches
    {
        MdHtmlResult r;
        std::string h = Gen("alpha beta alpha gamma alpha\n", L"C:\\docs", L"alpha", false, &r);
        Check("find marks emitted", Has(h, "<mark id=\"mdfind-0\">") && r.matchCount == 3);
    }
    // document wrapper + theme CSS present
    {
        std::string h = Gen("hi\n");
        Check("doctype + article wrapper", Has(h, "<!doctype html>") && Has(h, "markdown-body"));
        Check("theme CSS variables", Has(h, "--bg:") && Has(h, ".hl-kw"));
        Check("reading measure", Has(h, "max-width:46rem"));
    }
    // US4: View Source mode — raw text escaped in <pre>, NOT parsed as Markdown
    {
        const MdTheme* t = MdThemeById("paper");
        MdHtmlResult r;
        MdBuildSourceHtml("# Heading\n<b>x</b>\n", *t, r, L"");
        Check("source in <pre>", Has(r.html, "<pre class=\"mdsource\">"));
        Check("source not parsed (literal #, no <h1>)", Has(r.html, "# Heading") && !Has(r.html, "<h1"));
        Check("source escapes embedded HTML", Has(r.html, "&lt;b&gt;x&lt;/b&gt;"));
    }
    // US3: find works in source view too
    {
        const MdTheme* t = MdThemeById("paper");
        MdHtmlResult r;
        MdBuildSourceHtml("foo bar foo baz\n", *t, r, L"foo");
        Check("source find marks", Has(r.html, "<mark id=\"mdfind-0\">") && r.matchCount == 2);
    }

    printf("\n=== htmlgen test: %d passed, %d failed ===\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
