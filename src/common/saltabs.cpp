// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <windows.h>
#include <string.h>
#include <math.h>

#include "salunicode.h"
#include "salpath.h"
#include "saltabs.h"

void SalTabRecordInit(CSalTabRecord* rec)
{
    if (rec == NULL)
        return;
    rec->Location[0] = 0;
    rec->ViewTemplateIndex = 2; // detailed view
    rec->SortType = 0;          // by name
    rec->ReverseSort = FALSE;
    rec->FilterEnabled = FALSE;
    lstrcpynA(rec->FilterMasks, "*.*", SAL_TAB_FILTER_MAX);
}

BOOL SalTabRecordClamp(CSalTabRecord* rec, int maxSortType)
{
    if (rec == NULL || rec->Location[0] == 0)
        return FALSE;
    if (rec->SortType < 0 || rec->SortType > maxSortType)
        rec->SortType = 0;
    if (rec->ViewTemplateIndex < 1)
        rec->ViewTemplateIndex = 2;
    rec->ReverseSort = rec->ReverseSort ? TRUE : FALSE;
    rec->FilterEnabled = rec->FilterEnabled ? TRUE : FALSE;
    if (rec->FilterMasks[0] == 0)
        lstrcpynA(rec->FilterMasks, "*.*", SAL_TAB_FILTER_MAX);
    return TRUE;
}

static BOOL IsSep(char c)
{
    return c == '\\' || c == '/';
}

// copies 'len' bytes of 'src' into 'title' (bounded), never leaving a torn
// multi-byte sequence at the end
static void CopyTitle(const char* src, int len, char* title, int titleSize)
{
    if (titleSize <= 0)
        return;
    if (len > titleSize - 1)
        len = titleSize - 1;
    memcpy(title, src, len);
    title[len] = 0;
    SalU8TrimIncompleteTail(title);
}

void SalTabTitleFromLocation(const char* location, char* title, int titleSize)
{
    if (title == NULL || titleSize <= 0)
        return;
    title[0] = 0;
    if (location == NULL || location[0] == 0)
        return;

    // "fsname:userpart": a colon that is not a drive letter's and that comes
    // before any separator
    const char* text = location;
    BOOL isFS = FALSE;
    const char* s = location;
    while (*s != 0 && !IsSep(*s) && *s != ':')
        s++;
    if (*s == ':' && s - location > 1)
    {
        isFS = TRUE;
        text = s + 1;
    }

    int len = (int)strlen(text);
    while (len > 1 && IsSep(text[len - 1]))
        len--;
    if (len == 0)
    {
        CopyTitle(location, (int)strlen(location), title, titleSize);
        return;
    }

    // drive root: "C:" or "C:\" -> "C:\"
    if (!isFS && len == 2 && text[1] == ':' &&
        ((text[0] >= 'A' && text[0] <= 'Z') || (text[0] >= 'a' && text[0] <= 'z')))
    {
        char root[4] = {text[0], ':', '\\', 0};
        CopyTitle(root, 3, title, titleSize);
        return;
    }
    // UNC root: "\\server" or "\\server\share" (no separator after the share
    // name) - on disk and in a network-neighbourhood file system alike
    if (len > 2 && IsSep(text[0]) && IsSep(text[1]))
    {
        int seps = 0;
        for (int i = 2; i < len; i++)
            if (IsSep(text[i]))
                seps++;
        if (seps <= 1)
        {
            CopyTitle(text, len, title, titleSize);
            return;
        }
    }
    if (isFS)
    {
        // "scheme://host" is a root: only a component after the host counts
        const char* scheme = strstr(text, "://");
        if (scheme != NULL && scheme + 3 <= text + len)
        {
            const char* host = scheme + 3;
            const char* p = host;
            while (p < text + len && !IsSep(*p))
                p++;
            if (p >= text + len) // no component after the host
            {
                CopyTitle(text, len, title, titleSize);
                return;
            }
        }
    }

    // the last component
    const char* last = text + len;
    while (last > text && !IsSep(last[-1]))
        last--;
    int compLen = (int)((text + len) - last);
    if (compLen == 0) // a bare root such as "\" or "/"
    {
        last = text;
        compLen = len;
    }
    CopyTitle(last, compLen, title, titleSize);
}

int SalTabsIndexAfterClose(int count, int closed, int active)
{
    if (count <= 1 || closed < 0 || closed >= count)
        return active;
    if (closed < active)
        return active - 1;
    if (closed > active)
        return active;
    // closing the active tab: the right neighbour takes its index, else the left one
    if (closed < count - 1)
        return closed;
    return closed - 1;
}

int SalTabsCycle(int count, int active, BOOL forward)
{
    if (count <= 0)
        return 0;
    if (active < 0 || active >= count)
        active = 0;
    if (forward)
        return (active + 1) % count;
    return (active + count - 1) % count;
}

void SalTabsMove(int count, int from, int to, int* active)
{
    if (from < 0 || from >= count || to < 0 || to >= count || from == to)
        return;
    if (active == NULL)
        return;
    int a = *active;
    if (a == from)
        a = to;
    else if (from < to)
    {
        if (a > from && a <= to)
            a--;
    }
    else
    {
        if (a >= to && a < from)
            a++;
    }
    *active = a;
}

//
// feature 312: the tab key table
//

// one key of the table (contracts/tab-keys.md, rows 1-10 in display order)
struct CSalTabKeyDef
{
    int Vk;
    int Mods;
    int Classic; // its action with the option off (rows 5, 6, 8, 9: while tabs are on)
    int Browser; // its action in the browser-like mode
};

static const CSalTabKeyDef SalTabKeyTable[] = {
    {'T', SAL_TABKEY_CTRL, stkaGoToShortcut, stkaNewTab},
    {'W', SAL_TABKEY_CTRL, stkaRestoreSel, stkaCloseTab},
    {VK_NEXT, SAL_TABKEY_CTRL, stkaEnterFocused, stkaNextTab},
    {VK_PRIOR, SAL_TABKEY_CTRL, stkaParentDir, stkaPrevTab},
    {'T', SAL_TABKEY_CTRL | SAL_TABKEY_SHIFT, stkaNewTab, stkaReopenTab},
    {'W', SAL_TABKEY_CTRL | SAL_TABKEY_SHIFT, stkaCloseTab, stkaRestoreSel},
    {'G', SAL_TABKEY_CTRL | SAL_TABKEY_SHIFT, stkaNone, stkaGoToShortcut},
    {VK_NEXT, SAL_TABKEY_CTRL | SAL_TABKEY_SHIFT, stkaNextTab, stkaNextTab},
    {VK_PRIOR, SAL_TABKEY_CTRL | SAL_TABKEY_SHIFT, stkaPrevTab, stkaPrevTab},
    {VK_TAB, SAL_TABKEY_CTRL, stkaCommandLine, stkaCommandLine},
};

static const CSalTabKeyDef* SalTabKeyFind(int vk, int mods)
{
    if ((mods & SAL_TABKEY_ALT) != 0)
        return NULL;
    for (int i = 0; i < (int)(sizeof(SalTabKeyTable) / sizeof(SalTabKeyTable[0])); i++)
    {
        if (SalTabKeyTable[i].Vk == vk && SalTabKeyTable[i].Mods == mods)
            return &SalTabKeyTable[i];
    }
    return NULL;
}

static BOOL SalTabKeyIsTabAction(int action)
{
    return action == stkaNewTab || action == stkaCloseTab || action == stkaNextTab ||
           action == stkaPrevTab || action == stkaReopenTab;
}

BOOL SalTabKeysBrowserLike(BOOL tabsOn, BOOL optionOn)
{
    return tabsOn && optionOn;
}

int SalTabKeyMeaning(int vk, int mods, BOOL browserLike)
{
    const CSalTabKeyDef* def = SalTabKeyFind(vk, mods);
    if (def == NULL)
        return stkaNone;
    return browserLike ? def->Browser : def->Classic;
}

int SalTabKeyDispatch(int vk, int mods, BOOL browserLike)
{
    const CSalTabKeyDef* def = SalTabKeyFind(vk, mods);
    if (def == NULL)
        return stkaNone;
    int action = browserLike ? def->Browser : def->Classic;
    if (action == stkaNone || action == stkaCommandLine)
        return stkaNone;
    // a key keeping its classic non-tab meaning stays with its existing code
    if (action == def->Classic && !SalTabKeyIsTabAction(action))
        return stkaNone;
    return action;
}

int SalTabKeyRows(BOOL browserLike, CSalTabKeyRow* rows, int max)
{
    if (rows == NULL || max <= 0)
        return 0;
    int n = 0;
    for (int i = 0; i < (int)(sizeof(SalTabKeyTable) / sizeof(SalTabKeyTable[0])) && n < max; i++)
    {
        rows[n].Vk = SalTabKeyTable[i].Vk;
        rows[n].Mods = SalTabKeyTable[i].Mods;
        rows[n].Action = browserLike ? SalTabKeyTable[i].Browser : SalTabKeyTable[i].Classic;
        n++;
    }
    if (!browserLike && n < max) // Reopen Closed Tab has no key in the classic mode
    {
        rows[n].Vk = 0;
        rows[n].Mods = 0;
        rows[n].Action = stkaReopenTab;
        n++;
    }
    return n;
}

BOOL SalTabKeyForAction(int action, BOOL browserLike, int* vk, int* mods)
{
    if (vk != NULL)
        *vk = 0;
    if (mods != NULL)
        *mods = 0;
    if (action == stkaNone)
        return FALSE;
    for (int i = 0; i < (int)(sizeof(SalTabKeyTable) / sizeof(SalTabKeyTable[0])); i++)
    {
        int a = browserLike ? SalTabKeyTable[i].Browser : SalTabKeyTable[i].Classic;
        if (a == action)
        {
            if (vk != NULL)
                *vk = SalTabKeyTable[i].Vk;
            if (mods != NULL)
                *mods = SalTabKeyTable[i].Mods;
            return TRUE;
        }
    }
    return FALSE;
}

static BOOL SalTabAppend(char* out, int size, int* len, const char* s)
{
    int l = (int)strlen(s);
    if (*len + l + 1 > size)
        return FALSE;
    memcpy(out + *len, s, l + 1);
    *len += l;
    return TRUE;
}

BOOL SalTabKeyText(int vk, int mods, char* out, int size)
{
    if (out == NULL || size <= 0)
        return FALSE;
    out[0] = 0;
    if (vk == 0)
        return TRUE;
    char key[2] = {0, 0};
    const char* name;
    if (vk == VK_NEXT)
        name = "Page Down";
    else if (vk == VK_PRIOR)
        name = "Page Up";
    else if (vk == VK_TAB)
        name = "Tab";
    else if ((vk >= 'A' && vk <= 'Z') || (vk >= '0' && vk <= '9'))
    {
        key[0] = (char)vk;
        name = key;
    }
    else
        return FALSE;
    int len = 0;
    BOOL ok = TRUE;
    if ((mods & SAL_TABKEY_CTRL) != 0)
        ok = ok && SalTabAppend(out, size, &len, "Ctrl+");
    if ((mods & SAL_TABKEY_ALT) != 0)
        ok = ok && SalTabAppend(out, size, &len, "Alt+");
    if ((mods & SAL_TABKEY_SHIFT) != 0)
        ok = ok && SalTabAppend(out, size, &len, "Shift+");
    ok = ok && SalTabAppend(out, size, &len, name);
    if (!ok)
        out[0] = 0;
    return ok;
}

BOOL SalTabLabelWithKey(const char* label, const char* keyText, char* out, int size)
{
    if (out == NULL || size <= 0)
        return FALSE;
    out[0] = 0;
    if (label == NULL)
        return FALSE;
    if (keyText == NULL)
        keyText = "";
    int textLen;    // the text part of the label
    BOOL paren = FALSE;
    const char* tab = strchr(label, '\t');
    if (tab != NULL)
        textLen = (int)(tab - label);
    else
    {
        textLen = (int)strlen(label);
        // "Text (Key)": the parenthesised part at the end is the key
        if (textLen > 0 && label[textLen - 1] == ')')
        {
            const char* open = NULL;
            for (const char* p = label; *p != 0; p++)
            {
                if (p[0] == ' ' && p[1] == '(')
                    open = p;
            }
            if (open != NULL)
            {
                textLen = (int)(open - label);
                paren = TRUE;
            }
        }
    }
    int keyLen = (int)strlen(keyText);
    int need = textLen + (keyLen > 0 ? (paren ? keyLen + 3 : keyLen + 1) : 0) + 1;
    if (need > size)
        return FALSE;
    memcpy(out, label, textLen);
    int len = textLen;
    if (keyLen > 0)
    {
        if (paren)
        {
            memcpy(out + len, " (", 2);
            len += 2;
            memcpy(out + len, keyText, keyLen);
            len += keyLen;
            out[len++] = ')';
        }
        else
        {
            out[len++] = '\t';
            memcpy(out + len, keyText, keyLen);
            len += keyLen;
        }
    }
    out[len] = 0;
    return TRUE;
}

int SalTabsReopenIndex(int count, int closedIndex)
{
    if (count < 0)
        count = 0;
    if (closedIndex < 0)
        return 0;
    return closedIndex < count ? closedIndex : count;
}

int SalCfgPageIndexFrom311(int index)
{
    return index >= 7 ? index + 1 : index;
}

//
// feature 404: the variant F tab strip
//

static int SalTabMixChannel(int a, int b, double t)
{
    double v = rint(a + (b - a) * t); // round half to even, as Math.Round in the mockup
    if (v < 0)
        v = 0;
    if (v > 255)
        v = 255;
    return (int)v;
}

DWORD SalTabMix(DWORD a, DWORD b, double t)
{
    int r = SalTabMixChannel((int)(a & 0xFF), (int)(b & 0xFF), t);
    int g = SalTabMixChannel((int)((a >> 8) & 0xFF), (int)((b >> 8) & 0xFF), t);
    int bl = SalTabMixChannel((int)((a >> 16) & 0xFF), (int)((b >> 16) & 0xFF), t);
    return (DWORD)r | ((DWORD)g << 8) | ((DWORD)bl << 16);
}

void SalTabStripColorsGet(DWORD face, DWORD shadow, DWORD highlight, DWORD text, BOOL dark,
                          BOOL highContrast, DWORD hcHighlight, DWORD hcHighlightText,
                          CSalTabStripColors* out)
{
    if (out == NULL)
        return;
    if (highContrast)
    {
        out->StripBk = face;
        out->DimText = text;
        out->HoverBk = hcHighlight;
        out->HoverText = hcHighlightText;
        out->Separator = text;
        return;
    }
    out->StripBk = SalTabMix(face, shadow, dark ? 0.5 : 0.22);
    out->DimText = SalTabMix(text, out->StripBk, dark ? 0.30 : 0.38);
    out->HoverBk = SalTabMix(out->StripBk, text, dark ? 0.10 : 0.07);
    out->HoverText = text;
    out->Separator = dark ? highlight : SalTabMix(shadow, out->StripBk, 0.30);
}

void SalTabCloseColors(DWORD bk, DWORD fg, BOOL dark, BOOL highContrast, DWORD* cross, DWORD* circle)
{
    if (cross != NULL)
        *cross = highContrast ? fg : SalTabMix(fg, bk, 0.25);
    if (circle != NULL)
        *circle = SalTabMix(bk, fg, (dark && !highContrast) ? 0.20 : 0.14);
}

int SalTabScaled(int px, int scalePercent)
{
    return MulDiv(px, scalePercent, 100);
}

int SalTabStripHeight(int fontHeight, int scalePercent)
{
    return 2 + fontHeight + 2 + SalTabScaled(2 + 8, scalePercent);
}

void SalTabStripWidths(int avgCharWidth, int scalePercent, int iconSize, int* minWidth, int* maxWidth)
{
    int fixed = SalTabScaled(2 * 10 + 8 + 6, scalePercent) + iconSize;
    if (minWidth != NULL)
        *minWidth = 6 * avgCharWidth + fixed;
    if (maxWidth != NULL)
        *maxWidth = 20 * avgCharWidth + fixed;
}

int SalTabDragSlot(int count, int tabWidth, int draggedLeft, int from)
{
    if (count <= 0)
        return 0;
    if (from < 0)
        from = 0;
    if (from > count - 1)
        from = count - 1;
    if (tabWidth <= 0)
        return from;
    // floor division, also for a left below the run's left
    int cell = draggedLeft >= 0 ? draggedLeft / tabWidth : -((-draggedLeft + tabWidth - 1) / tabWidth);
    int slot;
    if (draggedLeft >= from * tabWidth)
        slot = cell; // moving right: tab j gives way once the left is at or above j * width (centre over centre)
    else
    {
        // moving left: tab j gives way once the left is at or below j * width, so the
        // left end of the run (the caller clamps the left to 0) is slot 0 (feature 413)
        slot = (cell * tabWidth == draggedLeft) ? cell : cell + 1;
    }
    if (slot < 0)
        slot = 0;
    if (slot > count - 1)
        slot = count - 1;
    return slot;
}

int SalTabColorDistance(DWORD a, DWORD b)
{
    int d = 0;
    int shift;
    for (shift = 0; shift <= 16; shift += 8)
    {
        int x = (int)((a >> shift) & 0xFF) - (int)((b >> shift) & 0xFF);
        if (x < 0)
            x = -x;
        if (x > d)
            d = x;
    }
    return d;
}

DWORD SalTabActiveFill(DWORD capBk, DWORD capFg, DWORD stripBk, DWORD face, BOOL highContrast)
{
    if (highContrast)
        return capBk;
    int k;
    for (k = 0; k <= 50; k++)
    {
        DWORD fill = k == 0 ? capBk : SalTabMix(capBk, capFg, k / 100.0);
        if (SalTabColorDistance(fill, stripBk) >= SALTAB_ACTIVE_MIN_CONTRAST &&
            SalTabColorDistance(fill, face) >= SALTAB_ACTIVE_MIN_CONTRAST)
            return fill;
    }
    return SalTabMix(capBk, capFg, 0.5);
}

static double SalTabLinear(int c)
{
    double v = c / 255.0;
    return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
}

static double SalTabLuminance(DWORD c)
{
    return 0.2126 * SalTabLinear((int)(c & 0xFF)) + 0.7152 * SalTabLinear((int)((c >> 8) & 0xFF)) +
           0.0722 * SalTabLinear((int)((c >> 16) & 0xFF));
}

double SalTabContrastRatio(DWORD a, DWORD b)
{
    double la = SalTabLuminance(a) + 0.05;
    double lb = SalTabLuminance(b) + 0.05;
    return la > lb ? la / lb : lb / la;
}

DWORD SalTabActiveText(DWORD capFg, DWORD capBk, DWORD fill)
{
    if (fill == capBk)
        return capFg;
    double want = SalTabContrastRatio(capFg, capBk);
    if (want > 4.5)
        want = 4.5;
    if (SalTabContrastRatio(capFg, fill) >= want)
        return capFg;
    DWORD toward = SalTabLuminance(capFg) >= SalTabLuminance(fill) ? RGB(255, 255, 255) : RGB(0, 0, 0);
    int k;
    for (k = 1; k <= 100; k++)
    {
        DWORD text = SalTabMix(capFg, toward, k / 100.0);
        if (SalTabContrastRatio(text, fill) >= want)
            return text;
    }
    return toward;
}

int SalTabDragPosition(int from, int slot, int index)
{
    if (index == from)
        return slot;
    if (from < slot && index > from && index <= slot)
        return index - 1;
    if (slot < from && index >= slot && index < from)
        return index + 1;
    return index;
}

int SalTabEaseOut(int elapsedMs, int durationMs)
{
    if (durationMs <= 0 || elapsedMs >= durationMs)
        return 1000;
    if (elapsedMs <= 0)
        return 0;
    double t = (double)elapsedMs / durationMs;
    double u = 1.0 - t;
    int p = (int)((1.0 - u * u * u) * 1000.0 + 0.5);
    return p > 1000 ? 1000 : p;
}

BOOL SalTabMenuCanMoveToOther(BOOL onTab, int count, BOOL otherShowsTabs)
{
    return (onTab && count > 1 && otherShowsTabs) ? TRUE : FALSE;
}

BOOL SalTabMenuCanNewAsOther(BOOL otherHasLocation)
{
    return otherHasLocation ? TRUE : FALSE;
}

BOOL SalTabArmDragAfterSwitch(BOOL downAtPress, BOOL downAfterSwitch)
{
    return (downAtPress && !downAfterSwitch) ? FALSE : TRUE;
}

static BOOL SalTabIsFsNameChar(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
           c == '_' || c == '-' || c == '.';
}

BOOL SalTabLocationsSame(const char* a, const char* b)
{
    if (a == NULL || b == NULL)
        return FALSE;
    return SalPathEqualOrdinalCI(a, b); // IsTheSamePath's rules: a leading / trailing backslash does not matter
}

int SalTabLocationKind(const char* location, int* fsNameLen)
{
    if (fsNameLen != NULL)
        *fsNameLen = 0;
    if (location == NULL || location[0] == 0)
        return SAL_TAB_KIND_FOLDER;
    const char* s = location;
    BOOL letter = (s[0] >= 'a' && s[0] <= 'z') || (s[0] >= 'A' && s[0] <= 'Z');
    if (letter && s[1] == ':')
    {
        if (s[2] == 0 || (s[2] == '\\' && s[3] == 0))
            return SAL_TAB_KIND_DRIVE;
        return SAL_TAB_KIND_FOLDER; // "X:\dir" (an archive is known only from the panel)
    }
    if (s[0] == '\\' && s[1] == '\\')
    {
        // "\\server\share" or "\\server\share\": exactly two non-empty components
        const char* p = s + 2;
        const char* server = p;
        while (*p != 0 && *p != '\\')
            p++;
        if (p == server || *p != '\\')
            return SAL_TAB_KIND_FOLDER;
        p++;
        const char* share = p;
        while (*p != 0 && *p != '\\')
            p++;
        if (p == share)
            return SAL_TAB_KIND_FOLDER;
        if (*p == 0 || (*p == '\\' && p[1] == 0))
            return SAL_TAB_KIND_UNC;
        return SAL_TAB_KIND_FOLDER;
    }
    int n = 0;
    while (SalTabIsFsNameChar(s[n]))
        n++;
    if (n >= 2 && s[n] == ':')
    {
        if (fsNameLen != NULL)
            *fsNameLen = n;
        return SAL_TAB_KIND_PLUGINFS;
    }
    return SAL_TAB_KIND_FOLDER;
}
