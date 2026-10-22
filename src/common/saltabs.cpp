// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <windows.h>
#include <string.h>

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
