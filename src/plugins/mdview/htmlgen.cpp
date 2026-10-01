// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// htmlgen.cpp - Markdown (UTF-8) -> HTML document, via md4c's SAX parser.
// Pure; no I/O, no network. Raw embedded HTML is emitted verbatim
// (FR-020/FR-022); text is HTML-escaped; images are classified and rewritten
// to the interceptor origin; script-free find wraps matches in <mark>.

#include "precomp.h"
#include "render.h"
#include "htmlgen.h"

extern "C" {
#include "md4c.h"
}

namespace
{

// --------------------------------------------------------------------------
// small utilities
// --------------------------------------------------------------------------

std::wstring Utf8ToW(const char* s, size_t n)
{
    if (n == 0) return std::wstring();
    int need = MultiByteToWideChar(CP_UTF8, 0, s, (int)n, NULL, 0);
    std::wstring w;
    w.resize(need > 0 ? need : 0);
    if (need > 0) MultiByteToWideChar(CP_UTF8, 0, s, (int)n, &w[0], need);
    return w;
}
std::wstring Utf8ToW(const std::string& s) { return Utf8ToW(s.data(), s.size()); }

std::string WToUtf8(const std::wstring& w)
{
    if (w.empty()) return std::string();
    int need = WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), NULL, 0, NULL, NULL);
    std::string s;
    s.resize(need > 0 ? need : 0);
    if (need > 0) WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), &s[0], need, NULL, NULL);
    return s;
}

void HexColor(std::string& o, COLORREF c)
{
    char b[8];
    // no GetGValue: its (WORD) cast trips /RTCc (SmallerTypeCheck) in debug
    sprintf_s(b, "#%02x%02x%02x", (unsigned)(c & 0xFF), (unsigned)((c >> 8) & 0xFF), (unsigned)((c >> 16) & 0xFF));
    o += b;
}

// escape into HTML text/attribute context
void Esc(std::string& o, const char* t, size_t n, bool attr)
{
    for (size_t i = 0; i < n; i++)
    {
        char c = t[i];
        switch (c)
        {
        case '&': o += "&amp;"; break;
        case '<': o += "&lt;"; break;
        case '>': o += "&gt;"; break;
        case '"': if (attr) o += "&quot;"; else o += '"'; break;
        default: o += c; break;
        }
    }
}
void Esc(std::string& o, const std::string& s, bool attr) { Esc(o, s.data(), s.size(), attr); }

std::string AttrStr(const MD_ATTRIBUTE& a)
{
    if (a.text == NULL) return std::string();
    return std::string(a.text, a.size);
}

bool StartsWithCI(const std::wstring& s, const wchar_t* p)
{
    size_t i = 0;
    for (; p[i]; i++)
        if (i >= s.size() || towlower(s[i]) != p[i]) return false;
    return true;
}

const char* HlClass(int cf)
{
    switch (cf)
    {
    case MDCF_KEYWORD: return "hl-kw";
    case MDCF_STRING: return "hl-str";
    case MDCF_NUMBER: return "hl-num";
    case MDCF_COMMENT: return "hl-cmt";
    case MDCF_TYPE: return "hl-type";
    case MDCF_FUNC: return "hl-fn";
    case MDCF_OP: return "hl-op";
    default: return NULL;
    }
}

// classify an image src (string form). 0=local relative, 1=remote, 2=refused
int ClassifyImage(const std::wstring& src, const std::wstring& docDir, std::wstring& resolved)
{
    std::wstring low = src;
    for (wchar_t& c : low) c = (wchar_t)towlower(c);
    if (StartsWithCI(low, L"http://") || StartsWithCI(low, L"https://")) { resolved = src; return 1; }
    if (low.rfind(L"//", 0) == 0) return 2;            // protocol-relative
    size_t colon = src.find(L':');
    if (colon != std::wstring::npos && colon > 0) return 2; // drive letter or scheme
    if (!src.empty() && (src[0] == L'/' || src[0] == L'\\')) return 2; // absolute
    if (src.find(L"..") != std::wstring::npos) return 2;   // traversal
    if (docDir.empty()) return 2;
    std::wstring full = docDir;
    if (!full.empty() && full.back() != L'\\' && full.back() != L'/') full += L'\\';
    std::wstring rel = src;
    for (wchar_t& c : rel) if (c == L'/') c = L'\\';
    full += rel;
    resolved = full;
    return 0;
}

// Strip a leading YAML front-matter block (--- ... --- / ...) which md4c does
// not understand and would otherwise render as a thematic break + heading.
void StripFrontMatter(std::string& s)
{
    if (!(s.size() >= 3 && s[0] == '-' && s[1] == '-' && s[2] == '-')) return;
    size_t nl = s.find('\n');
    if (nl == std::string::npos) return;
    std::string first = s.substr(0, nl);
    if (!first.empty() && first.back() == '\r') first.pop_back();
    if (first != "---") return;
    size_t pos = nl + 1;
    while (pos < s.size())
    {
        size_t e = s.find('\n', pos);
        size_t lineEnd = (e == std::string::npos) ? s.size() : e;
        std::string line = s.substr(pos, lineEnd - pos);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line == "---" || line == "...")
        {
            s.erase(0, (e == std::string::npos) ? s.size() : e + 1);
            return;
        }
        if (e == std::string::npos) break;
        pos = e + 1;
    }
}

// --------------------------------------------------------------------------
// generation state
// --------------------------------------------------------------------------

struct Gen
{
    std::string body;
    std::string* target; // current sink (&body, or &headBuf inside a heading)
    const MdTheme* theme;
    std::wstring docDir;
    MdHtmlResult* res;
    bool allowRemote;
    std::string findLowerA; // ASCII-lowercased UTF-8 find term ("" = none)

    // image alt buffering
    int imgDepth;
    std::string altBuf;
    std::string imgSrc, imgTitle;
    // code block buffering
    int codeDepth;
    std::string codeBuf, codeLang;
    // raw HTML block
    int rawHtml;
    // heading buffering
    int headingLevel;
    std::string headBuf, headPlain;
    // limits
    size_t depth;
    MdRenderLimits lim;
    bool capped;
};

bool Over(Gen& g) { return g.capped || g.body.size() + g.headBuf.size() > g.lim.maxNodesText; }

void EmitText(Gen& g, std::string& o, const char* t, size_t n)
{
    if (g.headingLevel > 0) g.headPlain.append(t, n);
    if (g.findLowerA.empty()) { Esc(o, t, n, false); return; }
    std::string low(t, n);
    for (char& c : low) if (c >= 'A' && c <= 'Z') c += 32;
    const std::string& f = g.findLowerA;
    size_t i = 0;
    while (i < n)
    {
        size_t pos = low.find(f, i);
        if (pos == std::string::npos) { Esc(o, t + i, n - i, false); break; }
        Esc(o, t + i, pos - i, false);
        o += "<mark id=\"mdfind-";
        o += std::to_string(g.res->matchCount++);
        o += "\">";
        Esc(o, t + pos, f.size(), false);
        o += "</mark>";
        i = pos + f.size();
    }
}

void EmitCell(Gen& g, const char* tag, const MD_BLOCK_TD_DETAIL* d)
{
    std::string& o = *g.target;
    o += '<'; o += tag;
    if (d)
    {
        const char* a = NULL;
        switch (d->align)
        {
        case MD_ALIGN_LEFT: a = "left"; break;
        case MD_ALIGN_CENTER: a = "center"; break;
        case MD_ALIGN_RIGHT: a = "right"; break;
        default: a = NULL; break;
        }
        if (a) { o += " style=\"text-align:"; o += a; o += "\""; }
    }
    o += '>';
}

void EmitCodeBlock(Gen& g)
{
    std::string& o = *g.target;
    o += "<pre><code";
    if (!g.codeLang.empty())
    {
        o += " class=\"language-";
        Esc(o, g.codeLang, true);
        o += "\"";
    }
    o += ">";
    std::wstring wcode = Utf8ToW(g.codeBuf);
    std::vector<HlRun> runs;
    HighlightCode(wcode, g.codeLang, runs);
    if (runs.empty())
    {
        Esc(o, g.codeBuf.data(), g.codeBuf.size(), false);
    }
    else
    {
        size_t N = wcode.size();
        for (size_t i = 0; i < N;)
        {
            int col = 0;
            for (const HlRun& r : runs)
                if (i >= r.start && i < r.start + r.len) { col = r.colorCf; break; }
            size_t j = i;
            while (j < N)
            {
                int c2 = 0;
                for (const HlRun& r : runs)
                    if (j >= r.start && j < r.start + r.len) { c2 = r.colorCf; break; }
                if (c2 != col) break;
                j++;
            }
            std::string seg = WToUtf8(wcode.substr(i, j - i));
            const char* cls = HlClass(col);
            if (cls) { o += "<span class=\""; o += cls; o += "\">"; Esc(o, seg, false); o += "</span>"; }
            else Esc(o, seg, false);
            i = j;
        }
    }
    o += "</code></pre>\n";
}

void EmitImage(Gen& g)
{
    std::string& o = *g.target;
    std::wstring wsrc = Utf8ToW(g.imgSrc);
    if (StartsWithCI(wsrc, L"data:"))
    {
        o += "<img src=\""; Esc(o, g.imgSrc, true); o += "\" alt=\""; o += g.altBuf; o += "\">";
        return;
    }
    std::wstring resolved;
    int kind = ClassifyImage(wsrc, g.docDir, resolved);
    if (kind == 2 || (kind == 1 && !g.allowRemote))
    {
        o += "<span class=\"md-imgph\" title=\"";
        Esc(o, g.imgSrc, true);
        o += "\">";
        if (!g.altBuf.empty()) o += g.altBuf; else Esc(o, g.imgSrc, false);
        o += "</span>";
        return;
    }
    int idx = (int)g.res->images.size();
    MdImageRef ref;
    ref.kind = (kind == 1) ? MdImageRef::Remote : MdImageRef::Local;
    ref.pathOrUrl = (kind == 1) ? wsrc : resolved;
    g.res->images.push_back(ref);
    o += "<img src=\"https://mdview.invalid/img/";
    o += std::to_string(idx);
    o += "\" alt=\""; o += g.altBuf; o += "\"";
    if (!g.imgTitle.empty()) { o += " title=\""; Esc(o, g.imgTitle, true); o += "\""; }
    o += ">";
}

// --------------------------------------------------------------------------
// md4c callbacks
// --------------------------------------------------------------------------

int EnterBlock(MD_BLOCKTYPE type, void* detail, void* ud)
{
    Gen& g = *(Gen*)ud;
    if (Over(g)) { g.capped = true; return 0; }
    std::string& o = *g.target;
    g.depth++;
    switch (type)
    {
    case MD_BLOCK_DOC: break;
    case MD_BLOCK_QUOTE: o += "<blockquote>\n"; break;
    case MD_BLOCK_UL: o += "<ul>\n"; break;
    case MD_BLOCK_OL:
    {
        MD_BLOCK_OL_DETAIL* d = (MD_BLOCK_OL_DETAIL*)detail;
        if (d && d->start != 1) { o += "<ol start=\""; o += std::to_string(d->start); o += "\">\n"; }
        else o += "<ol>\n";
        break;
    }
    case MD_BLOCK_LI:
    {
        MD_BLOCK_LI_DETAIL* d = (MD_BLOCK_LI_DETAIL*)detail;
        if (d && d->is_task)
        {
            bool checked = (d->task_mark == 'x' || d->task_mark == 'X');
            o += "<li class=\"task\"><input type=\"checkbox\" disabled";
            if (checked) o += " checked";
            o += "> ";
        }
        else o += "<li>";
        break;
    }
    case MD_BLOCK_HR: o += "<hr>\n"; break;
    case MD_BLOCK_H:
    {
        MD_BLOCK_H_DETAIL* d = (MD_BLOCK_H_DETAIL*)detail;
        g.headingLevel = d ? (int)d->level : 1;
        g.headBuf.clear();
        g.headPlain.clear();
        g.target = &g.headBuf;
        break;
    }
    case MD_BLOCK_CODE:
    {
        MD_BLOCK_CODE_DETAIL* d = (MD_BLOCK_CODE_DETAIL*)detail;
        g.codeDepth = 1;
        g.codeBuf.clear();
        g.codeLang.clear();
        if (d)
        {
            std::string lang = AttrStr(d->lang);
            for (char& c : lang) if (c >= 'A' && c <= 'Z') c += 32;
            g.codeLang = lang;
        }
        break;
    }
    case MD_BLOCK_HTML: g.rawHtml++; break;
    case MD_BLOCK_P: o += "<p>"; break;
    case MD_BLOCK_TABLE: o += "<table>\n"; break;
    case MD_BLOCK_THEAD: o += "<thead>\n"; break;
    case MD_BLOCK_TBODY: o += "<tbody>\n"; break;
    case MD_BLOCK_TR: o += "<tr>\n"; break;
    case MD_BLOCK_TH: EmitCell(g, "th", (MD_BLOCK_TD_DETAIL*)detail); break;
    case MD_BLOCK_TD: EmitCell(g, "td", (MD_BLOCK_TD_DETAIL*)detail); break;
    default: break;
    }
    return 0;
}

int LeaveBlock(MD_BLOCKTYPE type, void* detail, void* ud)
{
    Gen& g = *(Gen*)ud;
    (void)detail;
    if (g.depth > 0) g.depth--;
    switch (type)
    {
    case MD_BLOCK_DOC: break;
    case MD_BLOCK_QUOTE: *g.target += "</blockquote>\n"; break;
    case MD_BLOCK_UL: *g.target += "</ul>\n"; break;
    case MD_BLOCK_OL: *g.target += "</ol>\n"; break;
    case MD_BLOCK_LI: *g.target += "</li>\n"; break;
    case MD_BLOCK_HR: break;
    case MD_BLOCK_H:
    {
        int lvl = g.headingLevel;
        g.headingLevel = 0;
        g.target = &g.body;
        std::wstring slug = MdSlug(Utf8ToW(g.headPlain));
        // de-duplicate slugs
        std::wstring uniq = slug;
        int dup = 1;
        for (;;)
        {
            bool taken = false;
            for (const std::wstring& a : g.res->anchors)
                if (a == uniq) { taken = true; break; }
            if (!taken) break;
            uniq = slug + L"-" + std::to_wstring(dup++);
        }
        g.res->anchors.push_back(uniq);
        std::string idUtf8 = WToUtf8(uniq);
        g.body += "<h"; g.body += (char)('0' + (lvl < 1 ? 1 : lvl > 6 ? 6 : lvl));
        g.body += " id=\""; Esc(g.body, idUtf8, true); g.body += "\">";
        g.body += g.headBuf;
        g.body += "</h"; g.body += (char)('0' + (lvl < 1 ? 1 : lvl > 6 ? 6 : lvl));
        g.body += ">\n";
        break;
    }
    case MD_BLOCK_CODE: EmitCodeBlock(g); g.codeDepth = 0; break;
    case MD_BLOCK_HTML: if (g.rawHtml > 0) g.rawHtml--; break;
    case MD_BLOCK_P: *g.target += "</p>\n"; break;
    case MD_BLOCK_TABLE: *g.target += "</table>\n"; break;
    case MD_BLOCK_THEAD: *g.target += "</thead>\n"; break;
    case MD_BLOCK_TBODY: *g.target += "</tbody>\n"; break;
    case MD_BLOCK_TR: *g.target += "</tr>\n"; break;
    case MD_BLOCK_TH: *g.target += "</th>\n"; break;
    case MD_BLOCK_TD: *g.target += "</td>\n"; break;
    default: break;
    }
    return 0;
}

int EnterSpan(MD_SPANTYPE type, void* detail, void* ud)
{
    Gen& g = *(Gen*)ud;
    if (g.imgDepth > 0) { if (type == MD_SPAN_IMG) g.imgDepth++; return 0; }
    std::string& o = *g.target;
    switch (type)
    {
    case MD_SPAN_EM: o += "<em>"; break;
    case MD_SPAN_STRONG: o += "<strong>"; break;
    case MD_SPAN_U: o += "<u>"; break;
    case MD_SPAN_DEL: o += "<del>"; break;
    case MD_SPAN_CODE: o += "<code>"; break;
    case MD_SPAN_SUBSCRIPT: o += "<sub>"; break;
    case MD_SPAN_SUPERSCRIPT: o += "<sup>"; break;
    case MD_SPAN_MARK: o += "<mark>"; break;
    case MD_SPAN_A:
    {
        MD_SPAN_A_DETAIL* d = (MD_SPAN_A_DETAIL*)detail;
        o += "<a href=\"";
        if (d) Esc(o, AttrStr(d->href), true);
        o += "\"";
        if (d && d->title.text) { o += " title=\""; Esc(o, AttrStr(d->title), true); o += "\""; }
        o += ">";
        break;
    }
    case MD_SPAN_IMG:
    {
        MD_SPAN_IMG_DETAIL* d = (MD_SPAN_IMG_DETAIL*)detail;
        g.imgDepth = 1;
        g.altBuf.clear();
        g.imgSrc = d ? AttrStr(d->src) : std::string();
        g.imgTitle = d ? AttrStr(d->title) : std::string();
        break;
    }
    default: break; // latexmath, wikilink, spoiler, footnote-ref: neutral
    }
    return 0;
}

int LeaveSpan(MD_SPANTYPE type, void* detail, void* ud)
{
    Gen& g = *(Gen*)ud;
    (void)detail;
    if (type == MD_SPAN_IMG)
    {
        if (g.imgDepth > 0) g.imgDepth--;
        if (g.imgDepth == 0) EmitImage(g);
        return 0;
    }
    if (g.imgDepth > 0) return 0;
    std::string& o = *g.target;
    switch (type)
    {
    case MD_SPAN_EM: o += "</em>"; break;
    case MD_SPAN_STRONG: o += "</strong>"; break;
    case MD_SPAN_U: o += "</u>"; break;
    case MD_SPAN_DEL: o += "</del>"; break;
    case MD_SPAN_CODE: o += "</code>"; break;
    case MD_SPAN_SUBSCRIPT: o += "</sub>"; break;
    case MD_SPAN_SUPERSCRIPT: o += "</sup>"; break;
    case MD_SPAN_MARK: o += "</mark>"; break;
    case MD_SPAN_A: o += "</a>"; break;
    default: break;
    }
    return 0;
}

// Raw HTML is passed through verbatim (FR-020) - except an http-equiv
// attribute, renamed to data-tc-equiv (feature 085, privacy defect F3). With
// scripts off, <meta http-equiv="refresh" content="N;url=..."> is the one way a
// document can navigate by itself; the shared host hands a navigation to the
// link handler only when the engine calls it user-initiated, but that flag
// reflects a recent key press or click (transient user activation), so a
// refresh timed to fire while the reader scrolls could pass as one. Renamed,
// the attribute is inert (refresh, set-cookie, default-style alike); the
// rendered document is otherwise unchanged. Only an attribute NAME is touched:
// "http-equiv" after white space, a quote or '/', followed by optional white
// space (space, tab, form feed, CR, LF - all HTML whitespace) and then '=' OR
// the end of this call. md4c delivers raw HTML at most a line per call (the
// line break and indentation as separate calls), so the '=' may arrive in a
// LATER call: "<meta http-equiv\n=\"refresh\" ...>" is valid HTML and was the
// bypass the second review found. A name never spans calls (it holds no
// whitespace). The cost of renaming at the end of a call: the bare word
// "http-equiv" ending a raw-HTML line of prose is renamed too - cosmetic.
static void AppendRawHtml(std::string& o, const MD_CHAR* text, MD_SIZE size)
{
    static const char kAttr[] = "http-equiv";
    const MD_SIZE kLen = (MD_SIZE)(sizeof(kAttr) - 1);
    MD_SIZE i = 0;
    while (i < size)
    {
        bool hit = false;
        if (i + kLen <= size && (i == 0 || (unsigned char)text[i - 1] <= ' ' || text[i - 1] == '"' ||
                                 text[i - 1] == '\'' || text[i - 1] == '/'))
        {
            MD_SIZE k = 0;
            while (k < kLen && (text[i + k] | 0x20) == kAttr[k])
                k++;
            if (k == kLen)
            {
                MD_SIZE j = i + kLen;
                while (j < size && (text[j] == ' ' || text[j] == '\t' || text[j] == '\f' ||
                                    text[j] == '\r' || text[j] == '\n'))
                    j++;
                hit = (j == size || text[j] == '=');
            }
        }
        if (hit)
        {
            o += "data-tc-equiv";
            i += kLen;
        }
        else
            o += text[i++];
    }
}

int Text(MD_TEXTTYPE type, const MD_CHAR* text, MD_SIZE size, void* ud)
{
    Gen& g = *(Gen*)ud;
    if (g.imgDepth > 0)
    {
        // image alt: plain, attribute-escaped
        if (type == MD_TEXT_BR || type == MD_TEXT_SOFTBR) g.altBuf += ' ';
        else Esc(g.altBuf, text, size, true);
        return 0;
    }
    if (g.codeDepth > 0)
    {
        if (type == MD_TEXT_BR || type == MD_TEXT_SOFTBR) g.codeBuf += '\n';
        else g.codeBuf.append(text, size);
        return 0;
    }
    std::string& o = *g.target;
    switch (type)
    {
    case MD_TEXT_NULLCHAR: o += "\xEF\xBF\xBD"; break; // U+FFFD
    case MD_TEXT_BR: o += "<br>\n"; break;
    case MD_TEXT_SOFTBR: o += '\n'; break;
    case MD_TEXT_HTML: AppendRawHtml(o, text, size); break; // raw HTML verbatim (FR-020), http-equiv neutralised (085)
    case MD_TEXT_ENTITY: o.append(text, size); break; // pass valid entity through
    default: EmitText(g, o, text, size); break;        // NORMAL / CODE / LATEXMATH
    }
    return 0;
}

} // namespace

// --------------------------------------------------------------------------
// public API
// --------------------------------------------------------------------------

std::string MdBuildThemeCss(const MdTheme& t)
{
    std::string c;
    c += ":root{";
    c += "--bg:"; HexColor(c, t.docBg); c += ";";
    c += "--fg:"; HexColor(c, t.body); c += ";";
    c += "--hd:"; HexColor(c, t.heading); c += ";";
    c += "--lk:"; HexColor(c, t.link); c += ";";
    c += "--lka:"; HexColor(c, t.linkActive); c += ";";
    c += "--qt:"; HexColor(c, t.quoteText); c += ";";
    c += "--qa:"; HexColor(c, t.quoteAccent); c += ";";
    c += "--cif:"; HexColor(c, t.codeInlineFg); c += ";";
    c += "--cib:"; HexColor(c, t.codeInlineBg); c += ";";
    c += "--cb:"; HexColor(c, t.codeBg); c += ";";
    c += "--cf:"; HexColor(c, t.codeText); c += ";";
    c += "--tb:"; HexColor(c, t.tableBorder); c += ";";
    c += "--th:"; HexColor(c, t.tableHeadBg); c += ";";
    c += "--rl:"; HexColor(c, t.rule); c += ";";
    c += "--imf:"; HexColor(c, t.imgFg); c += ";";
    c += "--imb:"; HexColor(c, t.imgBg); c += ";";
    c += "--kw:"; HexColor(c, t.syn.kw); c += ";";
    c += "--str:"; HexColor(c, t.syn.str); c += ";";
    c += "--num:"; HexColor(c, t.syn.num); c += ";";
    c += "--cmt:"; HexColor(c, t.syn.cmt); c += ";";
    c += "--typ:"; HexColor(c, t.syn.type); c += ";";
    c += "--fn:"; HexColor(c, t.syn.fn); c += ";";
    c += "--op:"; HexColor(c, t.syn.op); c += ";";
    c += "}\n";
    c +=
        "*{box-sizing:border-box}"
        "html,body{margin:0;padding:0;background:var(--bg);color:var(--fg);}"
        "body{font-family:'Segoe UI',system-ui,sans-serif;font-size:16px;line-height:1.6;"
        "-webkit-text-size-adjust:100%;}"
        ".markdown-body{max-width:46rem;margin:0 auto;padding:24px 28px 64px;}"
        ".markdown-body.full{max-width:none;}"
        "h1,h2,h3,h4,h5,h6{color:var(--hd);line-height:1.25;margin:1.4em 0 .5em;font-weight:600;}"
        "h1{font-size:2em;border-bottom:1px solid var(--tb);padding-bottom:.3em;}"
        "h2{font-size:1.5em;border-bottom:1px solid var(--tb);padding-bottom:.3em;}"
        "h3{font-size:1.25em;}h4{font-size:1em;}h5{font-size:.9em;}h6{font-size:.85em;color:var(--qt);}"
        "p{margin:.6em 0;}"
        "a{color:var(--lk);text-decoration:none;}a:hover{text-decoration:underline;color:var(--lka);}"
        "ul,ol{padding-left:1.8em;margin:.5em 0;}li{margin:.2em 0;}"
        "li.task{list-style:none;margin-left:-1.4em;}li.task input{margin-right:.5em;}"
        "blockquote{margin:.8em 0;padding:.2em 1em;color:var(--qt);"
        "border-left:.28em solid var(--qa);background:transparent;}"
        "code{font-family:Consolas,'Cascadia Mono',monospace;font-size:.92em;"
        "background:var(--cib);color:var(--cif);padding:.12em .35em;border-radius:4px;}"
        "pre{background:var(--cb);border:1px solid var(--tb);border-radius:6px;"
        "padding:12px 14px;overflow-x:auto;margin:.8em 0;}"
        "pre code{background:none;color:var(--cf);padding:0;font-size:.9em;line-height:1.5;"
        "white-space:pre;}"
        "hr{border:0;border-top:2px solid var(--rl);margin:1.4em 0;}"
        "table{border-collapse:collapse;margin:.8em 0;display:block;overflow-x:auto;max-width:100%;}"
        "th,td{border:1px solid var(--tb);padding:6px 12px;}"
        "thead th{background:var(--th);}"
        "tr:nth-child(even) td{background:rgba(127,127,127,.06);}"
        "img{max-width:100%;height:auto;border-radius:4px;}"
        ".md-imgph{display:inline-block;padding:.15em .5em;border:1px dashed var(--tb);"
        "border-radius:4px;color:var(--imf);background:var(--imb);font-size:.9em;}"
        "mark{background:#ffe58a;color:#000;border-radius:2px;}"
        "mark:target{background:#ff9f40;outline:2px solid #ff7a00;}"
        ".hl-kw{color:var(--kw);}.hl-str{color:var(--str);}.hl-num{color:var(--num);}"
        ".hl-cmt{color:var(--cmt);font-style:italic;}.hl-type{color:var(--typ);}"
        ".hl-fn{color:var(--fn);}.hl-op{color:var(--op);}";
    return c;
}

bool MdRenderHtml(const std::string& mdUtf8, const MdTheme& theme,
                  const std::wstring& docDir, MdHtmlResult& out,
                  const std::wstring& findTerm, bool allowRemote,
                  const MdRenderLimits& lim)
{
    out.html.clear();
    out.images.clear();
    out.anchors.clear();
    out.matchCount = 0;
    out.bytesOut = 0;

    Gen g;
    g.target = &g.body;
    g.theme = &theme;
    g.docDir = docDir;
    g.res = &out;
    g.allowRemote = allowRemote;
    g.imgDepth = 0;
    g.codeDepth = 0;
    g.rawHtml = 0;
    g.headingLevel = 0;
    g.depth = 0;
    g.lim = lim;
    g.capped = false;
    if (!findTerm.empty())
    {
        g.findLowerA = WToUtf8(findTerm);
        for (char& c : g.findLowerA) if (c >= 'A' && c <= 'Z') c += 32;
    }
    std::string md = mdUtf8;
    StripFrontMatter(md);
    g.body.reserve(md.size() * 2 + 4096);

    MD_PARSER parser;
    memset(&parser, 0, sizeof(parser));
    parser.abi_version = 0;
    parser.flags = MD_DIALECT_GITHUB | MD_FLAG_STRIKETHROUGH | MD_FLAG_TABLES |
                   MD_FLAG_TASKLISTS | MD_FLAG_PERMISSIVEAUTOLINKS;
    parser.enter_block = EnterBlock;
    parser.leave_block = LeaveBlock;
    parser.enter_span = EnterSpan;
    parser.leave_span = LeaveSpan;
    parser.text = Text;
    parser.debug_log = NULL;
    parser.syntax = NULL;

    md_parse(md.data(), (MD_SIZE)md.size(), &parser, &g);

    bool dark = theme.dark;
    out.html = "<!doctype html>\n<html><head><meta charset=\"utf-8\">"
               "<meta name=\"color-scheme\" content=\"";
    out.html += dark ? "dark" : "light";
    out.html += "\"><style>\n";
    out.html += MdBuildThemeCss(theme);
    out.html += "\n</style></head><body><article class=\"markdown-body\">\n";
    out.html += g.body;
    out.html += "\n</article></body></html>";
    out.bytesOut = out.html.size();
    return true;
}

bool MdBuildSourceHtml(const std::string& srcUtf8, const MdTheme& theme,
                       MdHtmlResult& out, const std::wstring& findTerm)
{
    out.html.clear();
    out.images.clear();
    out.anchors.clear();
    out.matchCount = 0;
    out.bytesOut = 0;

    std::string findLowerA;
    if (!findTerm.empty())
    {
        findLowerA = WToUtf8(findTerm);
        for (char& c : findLowerA) if (c >= 'A' && c <= 'Z') c += 32;
    }

    std::string body = "<pre class=\"mdsource\">";
    const std::string& s = srcUtf8;
    if (findLowerA.empty())
    {
        Esc(body, s.data(), s.size(), false);
    }
    else
    {
        std::string low = s;
        for (char& c : low) if (c >= 'A' && c <= 'Z') c += 32;
        size_t i = 0, n = s.size();
        while (i < n)
        {
            size_t pos = low.find(findLowerA, i);
            if (pos == std::string::npos) { Esc(body, s.data() + i, n - i, false); break; }
            Esc(body, s.data() + i, pos - i, false);
            body += "<mark id=\"mdfind-";
            body += std::to_string(out.matchCount++);
            body += "\">";
            Esc(body, s.data() + pos, findLowerA.size(), false);
            body += "</mark>";
            i = pos + findLowerA.size();
        }
    }
    body += "</pre>";

    out.html = "<!doctype html>\n<html><head><meta charset=\"utf-8\">"
               "<meta name=\"color-scheme\" content=\"";
    out.html += theme.dark ? "dark" : "light";
    out.html += "\"><style>\n";
    out.html += MdBuildThemeCss(theme);
    out.html += "\n.mdsource{white-space:pre-wrap;word-break:break-word;"
                "font-family:Consolas,'Cascadia Mono',monospace;font-size:.95em;line-height:1.5;"
                "color:var(--cf);background:var(--cb);border:1px solid var(--tb);"
                "border-radius:6px;padding:14px 16px;}";
    out.html += "\n</style></head><body><article class=\"markdown-body\">\n";
    out.html += body;
    out.html += "\n</article></body></html>";
    out.bytesOut = out.html.size();
    return true;
}
