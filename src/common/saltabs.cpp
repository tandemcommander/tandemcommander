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
