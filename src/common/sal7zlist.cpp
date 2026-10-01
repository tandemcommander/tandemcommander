// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Parser of the 7-Zip technical listing (feature 084), see sal7zlist.h.

#include "precomp.h"

#include <windows.h>

#include "sal7zlist.h"

namespace
{

// one line of the input without its line end
struct CLine
{
    const char* Text;
    int Len;
};

// returns the next line starting at *pos (CR before LF stripped); FALSE at the end
BOOL NextLine(const char* text, size_t len, size_t* pos, CLine* line)
{
    if (*pos >= len)
        return FALSE;
    size_t start = *pos;
    size_t end = start;
    while (end < len && text[end] != '\n')
        end++;
    *pos = end < len ? end + 1 : end;
    size_t lineEnd = end;
    if (lineEnd > start && text[lineEnd - 1] == '\r')
        lineEnd--;
    line->Text = text + start;
    line->Len = (int)(lineEnd - start);
    return TRUE;
}

BOOL IsSeparator(const CLine& line)
{
    if (line.Len != 10)
        return FALSE;
    for (int i = 0; i < 10; i++)
    {
        if (line.Text[i] != '-')
            return FALSE;
    }
    return TRUE;
}

// splits "Key = Value"; FALSE when the line has no " = "
BOOL SplitKeyValue(const CLine& line, CLine* key, CLine* value)
{
    for (int i = 0; i + 3 <= line.Len; i++)
    {
        if (line.Text[i] == ' ' && line.Text[i + 1] == '=' && line.Text[i + 2] == ' ')
        {
            key->Text = line.Text;
            key->Len = i;
            value->Text = line.Text + i + 3;
            value->Len = line.Len - i - 3;
            return TRUE;
        }
    }
    // "Key =" with an empty value (7-Zip prints "Packed Size = " with a trailing
    // space, but be lenient when a tool strips it)
    if (line.Len >= 2 && line.Text[line.Len - 1] == '=' && line.Text[line.Len - 2] == ' ')
    {
        key->Text = line.Text;
        key->Len = line.Len - 2;
        value->Text = line.Text + line.Len;
        value->Len = 0;
        return TRUE;
    }
    return FALSE;
}

BOOL KeyIs(const CLine& key, const char* name)
{
    int n = lstrlenA(name);
    return key.Len == n && memcmp(key.Text, name, n) == 0;
}

// decimal number; empty -> *empty = TRUE and 0; FALSE on any other character
BOOL ParseNumber(const CLine& value, unsigned __int64* number, BOOL* empty)
{
    *number = 0;
    *empty = value.Len == 0;
    for (int i = 0; i < value.Len; i++)
    {
        char c = value.Text[i];
        if (c < '0' || c > '9')
            return FALSE;
        unsigned __int64 next = *number * 10 + (unsigned)(c - '0');
        if (next / 10 != *number) // overflow
            return FALSE;
        *number = next;
    }
    return TRUE;
}

// reads exactly 'digits' digits at text[*i]
BOOL ReadDigits(const CLine& value, int* i, int digits, WORD* out)
{
    int v = 0;
    for (int k = 0; k < digits; k++)
    {
        if (*i >= value.Len || value.Text[*i] < '0' || value.Text[*i] > '9')
            return FALSE;
        v = v * 10 + (value.Text[*i] - '0');
        (*i)++;
    }
    *out = (WORD)v;
    return TRUE;
}

// "YYYY-MM-DD hh:mm:ss[.fffffff]"
BOOL ParseDate(const CLine& value, SYSTEMTIME* st)
{
    memset(st, 0, sizeof(*st));
    int i = 0;
    if (!ReadDigits(value, &i, 4, &st->wYear) || i >= value.Len || value.Text[i++] != '-' ||
        !ReadDigits(value, &i, 2, &st->wMonth) || i >= value.Len || value.Text[i++] != '-' ||
        !ReadDigits(value, &i, 2, &st->wDay) || i >= value.Len || value.Text[i++] != ' ' ||
        !ReadDigits(value, &i, 2, &st->wHour) || i >= value.Len || value.Text[i++] != ':' ||
        !ReadDigits(value, &i, 2, &st->wMinute) || i >= value.Len || value.Text[i++] != ':' ||
        !ReadDigits(value, &i, 2, &st->wSecond))
    {
        return FALSE;
    }
    if (i < value.Len && value.Text[i] != '.')
        return FALSE;
    if (st->wMonth < 1 || st->wMonth > 12 || st->wDay < 1 || st->wDay > 31 ||
        st->wHour > 23 || st->wMinute > 59 || st->wSecond > 59)
    {
        return FALSE;
    }
    return TRUE;
}

void ResetItem(CSal7zListItem* item, BOOL* any)
{
    memset(item, 0, sizeof(*item));
    *any = FALSE;
}

} // namespace

BOOL SalIs7zPathSafe(const char* path, int len)
{
    if (path == NULL || len <= 0)
        return FALSE;
    if (path[0] == '\\' || path[0] == '/')
        return FALSE;
    if (len >= 2 && path[1] == ':')
        return FALSE;
    int start = 0;
    for (int i = 0; i <= len; i++)
    {
        if (i == len || path[i] == '\\' || path[i] == '/')
        {
            int compLen = i - start;
            if (compLen == 2 && path[start] == '.' && path[start + 1] == '.')
                return FALSE;
            start = i + 1;
        }
    }
    return TRUE;
}

int SalParse7zTechList(const char* text, size_t len, FSal7zListItem callback, void* ctx,
                       int* errorLine)
{
    if (errorLine != NULL)
        *errorLine = 0;
    size_t pos = 0;
    int lineNo = 0;
    CLine line;

    // the bare listing has no preamble and no separator; a separator means the
    // listing was not made with -ba, so it may carry the archive's comment
    {
        size_t scan = 0;
        int scanNo = 0;
        while (NextLine(text, len, &scan, &line))
        {
            scanNo++;
            if (IsSeparator(line))
            {
                if (errorLine != NULL)
                    *errorLine = scanNo;
                return SAL7Z_NOT_BARE;
            }
        }
    }

    CSal7zListItem item;
    BOOL any; // the current block has at least one key line
    ResetItem(&item, &any);
    int itemLine = 0;
    BOOL more = TRUE;
    while (more)
    {
        more = NextLine(text, len, &pos, &line);
        if (more)
            lineNo++;
        CLine key, value;
        BOOL isKey = more && SplitKeyValue(line, &key, &value);
        // a block ends at a blank line, at the end of the text, or where the
        // next "Path =" begins without a blank line in between
        BOOL newPath = isKey && KeyIs(key, "Path") && item.Path != NULL;
        if (!more || (line.Len == 0) || newPath)
        {
            if (any)
            {
                if (item.Path == NULL)
                {
                    if (errorLine != NULL)
                        *errorLine = itemLine;
                    return SAL7Z_NO_PATH;
                }
                if (!SalIs7zPathSafe(item.Path, item.PathLen))
                {
                    if (errorLine != NULL)
                        *errorLine = itemLine;
                    return SAL7Z_UNSAFE_PATH;
                }
                if (!callback(&item, ctx))
                    return SAL7Z_STOPPED;
            }
            ResetItem(&item, &any);
            if (!newPath)
                continue;
        }
        if (!isKey)
            continue; // not a "Key = Value" line (e.g. a trailing summary) - ignored
        if (!any)
            itemLine = lineNo;
        any = TRUE;
        if (KeyIs(key, "Path"))
        {
            item.Path = value.Text;
            item.PathLen = value.Len;
            if (value.Len == 0)
            {
                if (errorLine != NULL)
                    *errorLine = lineNo;
                return SAL7Z_UNSAFE_PATH;
            }
        }
        else if (KeyIs(key, "Folder"))
        {
            if (value.Len >= 1 && value.Text[0] == '+')
                item.IsDir = TRUE;
        }
        else if (KeyIs(key, "Size"))
        {
            BOOL empty;
            if (!ParseNumber(value, &item.Size, &empty))
            {
                if (errorLine != NULL)
                    *errorLine = lineNo;
                return SAL7Z_BAD_SIZE;
            }
        }
        else if (KeyIs(key, "Packed Size"))
        {
            BOOL empty;
            if (ParseNumber(value, &item.PackedSize, &empty) && !empty)
                item.HasPackedSize = TRUE;
            else
                item.PackedSize = 0;
        }
        else if (KeyIs(key, "Modified"))
        {
            item.HasDate = ParseDate(value, &item.Modified);
        }
        else if (KeyIs(key, "Attributes"))
        {
            for (int i = 0; i < value.Len && value.Text[i] != ' '; i++)
            {
                switch (value.Text[i])
                {
                case 'D':
                    item.IsDir = TRUE;
                    break;
                case 'R':
                    item.Attributes |= FILE_ATTRIBUTE_READONLY;
                    break;
                case 'H':
                    item.Attributes |= FILE_ATTRIBUTE_HIDDEN;
                    break;
                case 'S':
                    item.Attributes |= FILE_ATTRIBUTE_SYSTEM;
                    break;
                case 'A':
                    item.Attributes |= FILE_ATTRIBUTE_ARCHIVE;
                    break;
                }
            }
        }
        else if (KeyIs(key, "Encrypted"))
        {
            if (value.Len >= 1 && value.Text[0] == '+')
                item.Encrypted = TRUE;
        }
        // any other key is ignored
    }
    return SAL7Z_OK;
}
