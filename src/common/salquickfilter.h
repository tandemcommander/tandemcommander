// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salquickfilter.h
//
// Pure rules of the panel's quick search (feature 244). Header-only, no
// globals; saltests checks them (contract specs/244-*/contracts/
// salquickfilter-rules.md).
//
//   SalQFMatchName    does a name match the typed text - at its start
//                     (PREFIX, the 0.1.10 rule) or anywhere (SUBSTRING)
//   SalQFChooseFocus  which item the focus goes to after the text changed
//   SalQFTint         the light tint of a searching panel's background
//   SalQFDistance     RGB distance of two colours
//   SalQFContrast     WCAG 2 contrast ratio of two colours
//
// The mask is what PrepareQSMask (src/masks.cpp) makes of the typed text:
// literal segments separated by '/', which stands for any run of characters.
// The prefix rule is the old matcher of the core, kept algorithm for
// algorithm: an ASCII mask against an ASCII name compares bytes with ASCII
// case folding (AgreeQSMaskAux; its LowerCase table folds ASCII bytes the
// same way), anything else compares literal segments against name prefixes
// at character boundaries with SalNameEqualCI (case + canonical equivalence),
// and a dot ending the mask is tolerated for a name without an extension.
// With 'substring' (the new mode) a name that is not ASCII, or a mask that is
// not, is matched by comparing KEYS (SalQFBuildKey): the name and each literal
// segment of the mask, canonically decomposed (NFD) and lower-cased, one key
// unit remembering the byte offset of the name's character it comes from. A
// match starts and ends on character boundaries of the name; the first segment
// at the start is a prefix match, else the leftmost start wins; later segments
// are taken at their first occurrence after the previous one; the dot
// tolerance applies to prefix matches. ASCII masks against ASCII names keep
// the byte-wise rule. Keys make a test cost one memcmp per start position: the
// old rule's SalNameEqualCI per position (a normalisation and two allocations
// each) made typing take seconds in large folders of non-ASCII names. Case and
// canonical equivalence are as in SalNameEqualCI; its linguistic extras (e.g.
// "ss" = "sharp s") belong to the 0.1.10 rule only ('substring' FALSE).
//
//*****************************************************************************

#include <windows.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "salunicode.h"

#define SALQF_NONE 0
#define SALQF_SUBSTRING 1
#define SALQF_PREFIX 2

struct CSalQFMatch
{
    int Kind;       // SALQF_NONE, SALQF_SUBSTRING or SALQF_PREFIX
    int MatchStart; // byte offset where the match starts in the name (0 for a prefix)
    int MatchEnd;   // byte offset behind the match (the old matcher's 'offset')
};

// The key of a UTF-8 (WTF-8) text: Units[0..Count) = the canonical decomposition in lower case;
// Offsets[i] = byte offset of the character unit i comes from, Offsets[Count] = the text's length;
// Starts[i] = 1 when unit i is the first unit of a character. One allocation (Block); free with
// SalQFFreeKey.
struct CSalQFKey
{
    WCHAR* Units;
    int* Offsets;
    BYTE* Starts;
    int Count;
    void* Block;
};

namespace SalQFDetail
{
    inline char AsciiLower(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c + ('a' - 'A')) : c; }

    // the key units of one character 'w' (1 or 2 UTF-16 units) computed by the system
    inline int CharKeySystem(const WCHAR* w, int wlen, WCHAR* out, int cap);

    // a character of the BMP has its key computed once (keys of 100,000 names would otherwise cost
    // two system calls per character); used from the GUI thread and the tests only
    struct CCharKeyCache
    {
        WCHAR Units[65536][4];
        BYTE Count[65536]; // 0 = not computed yet, 0xFF = longer than 4 units (computed every time)
    };
    inline CCharKeyCache* CharKeyCache()
    {
        static CCharKeyCache cache; // zero-initialised static storage (640 KB), not the heap
        return &cache;
    }

    // the key units of one character 'w' (1 or 2 UTF-16 units) into 'out' (capacity 'cap');
    // returns the count, 0 when it does not fit
    inline int CharKey(const WCHAR* w, int wlen, WCHAR* out, int cap)
    {
        if (wlen == 1 && w[0] < 0x80)
        {
            out[0] = (w[0] >= 'A' && w[0] <= 'Z') ? (WCHAR)(w[0] + ('a' - 'A')) : w[0];
            return 1;
        }
        CCharKeyCache* cache = wlen == 1 ? CharKeyCache() : NULL;
        if (cache != NULL)
        {
            BYTE n = cache->Count[w[0]];
            if (n == 0)
            {
                WCHAR tmp[32];
                int m = CharKeySystem(w, 1, tmp, _countof(tmp));
                if (m > 0 && m <= 4)
                {
                    memcpy(cache->Units[w[0]], tmp, m * sizeof(WCHAR));
                    cache->Count[w[0]] = (BYTE)m;
                    n = (BYTE)m;
                }
                else
                    cache->Count[w[0]] = 0xFF;
            }
            if (n != 0 && n != 0xFF)
            {
                if (n > cap)
                    return 0;
                memcpy(out, cache->Units[w[0]], n * sizeof(WCHAR));
                return n;
            }
        }
        return CharKeySystem(w, wlen, out, cap);
    }

    inline int CharKeySystem(const WCHAR* w, int wlen, WCHAR* out, int cap)
    {
        WCHAR nfd[32];
        int n = NormalizeString(NormalizationD, w, wlen, nfd, _countof(nfd));
        if (n <= 0) // not normalisable (a lone surrogate of WTF-8): the units as they are
        {
            n = wlen;
            memcpy(nfd, w, wlen * sizeof(WCHAR));
        }
        if (n > cap)
            return 0;
        int m = LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_LOWERCASE, nfd, n, out, cap, NULL, NULL, 0);
        if (m <= 0)
        {
            memcpy(out, nfd, n * sizeof(WCHAR));
            m = n;
        }
        return m;
    }

    // the old AgreeQSMaskAux (masks.cpp) with wholeString == FALSE, for ASCII names and masks
    inline BOOL AsciiAux(const char* filename, BOOL hasExtension, const char* filenameBase, const char* mask,
                         BOOL allowDot, int& offset)
    {
        while (*filename != 0)
        {
            if (*mask == 0)
            {
                offset = (int)(filename - filenameBase);
                return TRUE; // end of mask, 'offset' = how far it reaches into the name
            }
            if (AsciiLower(*filename) == AsciiLower(*mask))
            {
                filename++;
                mask++;
            }
            else if (*mask == '/') // '/' stands for a run of characters (can be empty)
            {
                mask++;
                while (*filename != 0)
                {
                    if (AsciiAux(filename, hasExtension, filenameBase, mask, allowDot, offset))
                        return TRUE;
                    filename++;
                }
                break; // end of name
            }
            else
                return FALSE;
        }
        if (*mask == 0 || allowDot && !hasExtension && *mask == '.' && *(mask + 1) == 0)
        {
            offset = (int)(filename - filenameBase);
            return TRUE; // the mask matched the entire name
        }
        return FALSE;
    }

    // the old AgreeQSMaskU8Aux (fileswn0.cpp) with wholeString == FALSE
    inline BOOL U8Aux(const char* filename, BOOL hasExtension, const char* filenameBase, const char* mask,
                      BOOL allowDot, int& offset)
    {
        while (*mask != 0)
        {
            if (*mask == '/')
            {
                mask++;
                const char* iter = filename;
                while (1)
                {
                    if (U8Aux(iter, hasExtension, filenameBase, mask, allowDot, offset))
                        return TRUE;
                    if (*iter == 0)
                        return FALSE;
                    iter = SalU8Next(iter);
                }
            }
            // literal segment up to the next wildcard or the end of the mask
            const char* segEnd = mask;
            while (*segEnd != 0 && *segEnd != '/')
                segEnd++;
            int segLen = (int)(segEnd - mask);
            int segChars = SalU8CharCount(mask, segLen);
            // canonical equivalence can change the character count (NFC vs. NFD), so
            // name prefixes somewhat longer than the segment are tried as well
            const char* p = filename;
            const char* matchEnd = NULL;
            int chars = 0;
            while (*p != 0 && chars < 3 * segChars + 3)
            {
                p = SalU8Next(p);
                chars++;
                if (SalNameEqualCI(mask, segLen, filename, (int)(p - filename)))
                {
                    matchEnd = p;
                    break;
                }
            }
            if (matchEnd == NULL)
            {
                // a dot at the end of the mask is tolerated for names without an extension
                if (allowDot && *segEnd == 0 && !hasExtension && segLen > 0 && mask[segLen - 1] == '.')
                {
                    int rest = (int)strlen(filename);
                    if (segLen == 1 && rest == 0 ||
                        segLen > 1 && SalNameEqualCI(mask, segLen - 1, filename, rest))
                    {
                        offset = (int)(filename - filenameBase) + rest;
                        return TRUE;
                    }
                }
                return FALSE;
            }
            filename = matchEnd;
            mask = segEnd;
        }
        offset = (int)(filename - filenameBase);
        return TRUE;
    }

    inline BOOL PrefixAt(const char* at, const char* base, BOOL hasExtension, const char* mask, BOOL ascii,
                         BOOL allowDot, int& end)
    {
        end = 0;
        return ascii ? AsciiAux(at, hasExtension, base, mask, allowDot, end)
                     : U8Aux(at, hasExtension, base, mask, allowDot, end);
    }

    // sRGB channel -> linear light (WCAG 2)
    inline double Linear(int c)
    {
        double v = c / 255.0;
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
    }
    inline double Luminance(COLORREF c)
    {
        return 0.2126 * Linear(GetRValue(c)) + 0.7152 * Linear(GetGValue(c)) + 0.0722 * Linear(GetBValue(c));
    }
    inline COLORREF Mix(COLORREF a, COLORREF b, int percentB)
    {
        int r = (GetRValue(a) * (100 - percentB) + GetRValue(b) * percentB + 50) / 100;
        int g = (GetGValue(a) * (100 - percentB) + GetGValue(b) * percentB + 50) / 100;
        int bl = (GetBValue(a) * (100 - percentB) + GetBValue(b) * percentB + 50) / 100;
        return RGB(r, g, bl);
    }
} // namespace SalQFDetail

// the visible difference the tint keeps from the normal background (RGB distance)
#define SALQF_TINT_MIN_DISTANCE 18.0

// Euclidean distance of two colours in RGB (0..441)
inline double SalQFDistance(COLORREF a, COLORREF b)
{
    double dr = (double)GetRValue(a) - GetRValue(b);
    double dg = (double)GetGValue(a) - GetGValue(b);
    double db = (double)GetBValue(a) - GetBValue(b);
    return sqrt(dr * dr + dg * dg + db * db);
}

// WCAG 2 contrast ratio (1..21)
inline double SalQFContrast(COLORREF a, COLORREF b)
{
    double la = SalQFDetail::Luminance(a) + 0.05;
    double lb = SalQFDetail::Luminance(b) + 0.05;
    return la > lb ? la / lb : lb / la;
}

inline void SalQFFreeKey(CSalQFKey& key)
{
    if (key.Block != NULL)
        free(key.Block);
    key.Block = NULL;
    key.Units = NULL;
    key.Offsets = NULL;
    key.Starts = NULL;
    key.Count = 0;
}

// Builds the key of 'textU8' ('len' bytes, -1 = up to the terminator). FALSE only without memory.
// A byte that is no UTF-8 / WTF-8 character is one unit of its own (0xDC00 + byte, as WTF-8 shows it).
inline BOOL SalQFBuildKey(const char* textU8, int len, CSalQFKey& key)
{
    key.Block = NULL;
    key.Units = NULL;
    key.Offsets = NULL;
    key.Starts = NULL;
    key.Count = 0;
    if (textU8 == NULL)
        return FALSE;
    if (len < 0)
        len = (int)strlen(textU8);
    // built in a scratch area (on the stack; a name - 255 UTF-16 units - decomposes into fewer than
    // 2048 units; a longer text grows it on the heap), then kept in one block of the exact size:
    // keys of 100,000 names must not cost a kilobyte each
    int cap = 2048;
    char stackBlock[2048 * (sizeof(int) + sizeof(WCHAR) + 1) + sizeof(int)];
    char* heapBlock = NULL;
    for (;;)
    {
        char* block = heapBlock != NULL ? heapBlock : stackBlock;
        int* offsets = (int*)block; // cap + 1 ints, then cap units, then cap flags
        WCHAR* units = (WCHAR*)(block + (cap + 1) * sizeof(int));
        BYTE* starts = (BYTE*)(block + (cap + 1) * sizeof(int) + cap * sizeof(WCHAR));
        int count = 0;
        BOOL fits = TRUE;
        const char* p = textU8;
        const char* end = textU8 + len;
        while (p < end)
        {
            // decode one WTF-8 character (a lone surrogate's 3-byte form included)
            const BYTE* b = (const BYTE*)p;
            int left = (int)(end - p);
            DWORD cp = 0;
            int len8 = 0;
            if (b[0] < 0x80)
                cp = b[0], len8 = 1;
            else if ((b[0] & 0xE0) == 0xC0 && left >= 2 && (b[1] & 0xC0) == 0x80)
            {
                cp = ((b[0] & 0x1F) << 6) | (b[1] & 0x3F);
                len8 = cp >= 0x80 ? 2 : 0;
            }
            else if ((b[0] & 0xF0) == 0xE0 && left >= 3 && (b[1] & 0xC0) == 0x80 && (b[2] & 0xC0) == 0x80)
            {
                cp = ((b[0] & 0x0F) << 12) | ((b[1] & 0x3F) << 6) | (b[2] & 0x3F);
                len8 = cp >= 0x800 ? 3 : 0;
            }
            else if ((b[0] & 0xF8) == 0xF0 && left >= 4 && (b[1] & 0xC0) == 0x80 && (b[2] & 0xC0) == 0x80 &&
                     (b[3] & 0xC0) == 0x80)
            {
                cp = ((b[0] & 0x07) << 18) | ((b[1] & 0x3F) << 12) | ((b[2] & 0x3F) << 6) | (b[3] & 0x3F);
                len8 = cp >= 0x10000 && cp <= 0x10FFFF ? 4 : 0;
            }
            WCHAR w[2];
            int wlen;
            const char* next;
            if (len8 == 0) // not a character: one unit per byte
            {
                w[0] = (WCHAR)(0xDC00 + b[0]);
                wlen = 1;
                next = p + 1;
            }
            else
            {
                if (cp < 0x10000)
                {
                    w[0] = (WCHAR)cp;
                    wlen = 1;
                }
                else
                {
                    w[0] = (WCHAR)(0xD800 + ((cp - 0x10000) >> 10));
                    w[1] = (WCHAR)(0xDC00 + ((cp - 0x10000) & 0x3FF));
                    wlen = 2;
                }
                next = p + len8;
            }
            int n = SalQFDetail::CharKey(w, wlen, units + count, cap - count);
            if (n == 0)
            {
                fits = FALSE;
                break;
            }
            for (int i = 0; i < n; i++)
            {
                offsets[count + i] = (int)(p - textU8);
                starts[count + i] = i == 0 ? 1 : 0;
            }
            count += n;
            p = next;
        }
        if (fits)
        {
            offsets[count] = len;
            char* exact = (char*)malloc((count + 1) * sizeof(int) + count * sizeof(WCHAR) + count + 1);
            if (exact != NULL)
            {
                memcpy(exact, offsets, (count + 1) * sizeof(int));
                memcpy(exact + (count + 1) * sizeof(int), units, count * sizeof(WCHAR));
                memcpy(exact + (count + 1) * sizeof(int) + count * sizeof(WCHAR), starts, count);
                key.Block = exact;
                key.Offsets = (int*)exact;
                key.Units = (WCHAR*)(exact + (count + 1) * sizeof(int));
                key.Starts = (BYTE*)(exact + (count + 1) * sizeof(int) + count * sizeof(WCHAR));
                key.Count = count;
            }
            if (heapBlock != NULL)
                free(heapBlock);
            return exact != NULL;
        }
        if (heapBlock != NULL)
            free(heapBlock);
        cap *= 2;
        heapBlock = (char*)malloc((cap + 1) * sizeof(int) + cap * sizeof(WCHAR) + cap);
        if (heapBlock == NULL)
            return FALSE;
    }
}

// The literal segments of a mask (PrepareQSMask output, '/' = any run of characters) as keys.
struct CSalQFMaskKeys
{
    CSalQFKey Segs[64];
    int Count;
    BOOL TooMany;     // more than 64 segments: nothing matches (never happens with typed text)
    BOOL LeadingWild; // the mask starts with '/': a match anywhere is a prefix match (as in 0.1.10)
    BOOL TrailingDot; // the last segment ends with '.': LastNoDot holds it without the dot
    CSalQFKey LastNoDot;
};

inline void SalQFFreeMaskKeys(CSalQFMaskKeys& mk)
{
    for (int i = 0; i < mk.Count; i++)
        SalQFFreeKey(mk.Segs[i]);
    mk.Count = 0;
    if (mk.TrailingDot)
        SalQFFreeKey(mk.LastNoDot);
    mk.TrailingDot = FALSE;
}

// FALSE only without memory
inline BOOL SalQFBuildMaskKeys(const char* mask, CSalQFMaskKeys& mk)
{
    mk.Count = 0;
    mk.TooMany = FALSE;
    mk.LeadingWild = *mask == '/';
    mk.TrailingDot = FALSE;
    mk.LastNoDot.Block = NULL;
    mk.LastNoDot.Count = 0;
    const char* p = mask;
    while (*p != 0)
    {
        while (*p == '/')
            p++;
        const char* e = p;
        while (*e != 0 && *e != '/')
            e++;
        if (e > p)
        {
            if (mk.Count == _countof(mk.Segs))
            {
                mk.TooMany = TRUE;
                break;
            }
            if (!SalQFBuildKey(p, (int)(e - p), mk.Segs[mk.Count]))
            {
                SalQFFreeMaskKeys(mk);
                return FALSE;
            }
            mk.Count++;
            if (*e == 0 && e[-1] == '.') // the last segment ends with a dot (PrepareQSMask drops a final '/')
            {
                if (!SalQFBuildKey(p, (int)(e - p) - 1, mk.LastNoDot))
                {
                    SalQFFreeMaskKeys(mk);
                    return FALSE;
                }
                mk.TrailingDot = TRUE;
            }
        }
        p = e;
    }
    return TRUE;
}

namespace SalQFDetail
{
    // does 'seg' lie at unit 'pos' of 'name', starting and ending on character boundaries
    inline BOOL KeySegAt(const CSalQFKey& name, int pos, const CSalQFKey& seg)
    {
        if (pos + seg.Count > name.Count || !name.Starts[pos])
            return FALSE;
        if (pos + seg.Count < name.Count && !name.Starts[pos + seg.Count])
            return FALSE;
        return memcmp(name.Units + pos, seg.Units, seg.Count * sizeof(WCHAR)) == 0;
    }
} // namespace SalQFDetail

namespace SalQFDetail
{
    // segments 1.. after unit 'pos', each at its first occurrence; 'noDot': the last one is
    // mk.LastNoDot and must end the name. Returns the end unit, or -1.
    inline int KeyRest(const CSalQFKey& name, const CSalQFMaskKeys& mk, int pos, BOOL noDot)
    {
        for (int k = 1; k < mk.Count; k++)
        {
            const CSalQFKey& seg = (noDot && k == mk.Count - 1) ? mk.LastNoDot : mk.Segs[k];
            if (noDot && k == mk.Count - 1)
            {
                int q = name.Count - seg.Count; // it ends the name
                if (q < pos || seg.Count > 0 && !KeySegAt(name, q, seg) || seg.Count == 0 && q != pos && !name.Starts[q])
                    return -1;
                return name.Count;
            }
            int q = pos;
            while (q + seg.Count <= name.Count && !KeySegAt(name, q, seg))
                q++;
            if (q + seg.Count > name.Count)
                return -1;
            pos = q + seg.Count;
        }
        return pos;
    }
    // the whole mask from unit 's' (the first segment there); -1 = no
    inline int KeyMatchAt(const CSalQFKey& name, const CSalQFMaskKeys& mk, int s, BOOL noDot)
    {
        const CSalQFKey& first = (noDot && mk.Count == 1) ? mk.LastNoDot : mk.Segs[0];
        if (noDot && mk.Count == 1) // the only segment, without its dot, is the rest of the name
        {
            if (s + first.Count != name.Count)
                return -1;
            if (first.Count > 0 && !KeySegAt(name, s, first))
                return -1;
            return name.Count;
        }
        if (!KeySegAt(name, s, first))
            return -1;
        return KeyRest(name, mk, s + first.Count, noDot);
    }
} // namespace SalQFDetail

// The leftmost match of the mask's segments in 'name' starting at a byte offset >= 'minStart'
// (1 = anywhere but at the start); the first segment at the start, each next one at its first
// occurrence after the previous one. Fills 'result' as SALQF_SUBSTRING.
inline BOOL SalQFKeyFind(const CSalQFKey& name, const CSalQFMaskKeys& mk, int minStart, CSalQFMatch& result)
{
    if (mk.Count == 0 || mk.TooMany)
        return FALSE;
    for (int s = 0; s + mk.Segs[0].Count <= name.Count; s++)
    {
        if (name.Offsets[s] < minStart || !name.Starts[s] || !SalQFDetail::KeySegAt(name, s, mk.Segs[0]))
            continue;
        int end = SalQFDetail::KeyRest(name, mk, s + mk.Segs[0].Count, FALSE);
        if (end < 0)
            return FALSE; // a later start finds the later segments no sooner
        result.Kind = SALQF_SUBSTRING;
        result.MatchStart = name.Offsets[s];
        result.MatchEnd = name.Offsets[end];
        return TRUE;
    }
    return FALSE;
}

// The rule of the new mode on keys: a prefix match (the first segment at the start, or anywhere
// after a leading '/'; a final '.' tolerated when the name has no extension), else a substring match.
inline BOOL SalQFMatchKeys(const CSalQFKey& name, BOOL hasExtension, const CSalQFMaskKeys& mk, CSalQFMatch& result)
{
    result.Kind = SALQF_NONE;
    result.MatchStart = 0;
    result.MatchEnd = 0;
    if (mk.TooMany)
        return FALSE;
    if (mk.Count == 0) // an empty mask (or only wildcards): everything, as in 0.1.10
    {
        result.Kind = SALQF_PREFIX;
        return TRUE;
    }
    for (int pass = 0; pass < 2; pass++) // the second pass: the dot tolerance
    {
        BOOL noDot = pass == 1;
        if (noDot && (!mk.TrailingDot || hasExtension))
            break;
        int lastStart = mk.LeadingWild ? name.Count : 0;
        for (int s = 0; s <= lastStart; s++)
        {
            if (s < name.Count && !name.Starts[s])
                continue;
            int end = SalQFDetail::KeyMatchAt(name, mk, s, noDot);
            if (end >= 0)
            {
                result.Kind = SALQF_PREFIX;
                result.MatchEnd = name.Offsets[end];
                return TRUE;
            }
        }
    }
    if (mk.LeadingWild)
        return FALSE; // every start was a prefix start
    return SalQFKeyFind(name, mk, 1, result);
}

// Does 'nameU8' match 'mask' (PrepareQSMask output)? 'substring' FALSE = the
// 0.1.10 rule only. Fills 'result' (Kind NONE when it does not match).
// 'nameKey'/'maskKeys': the keys when the caller keeps them (a scan of many names), else NULL.
inline BOOL SalQFMatchName(const char* nameU8, BOOL hasExtension, const char* mask, BOOL substring,
                           CSalQFMatch& result, const CSalQFKey* nameKey = NULL,
                           const CSalQFMaskKeys* maskKeys = NULL)
{
    result.Kind = SALQF_NONE;
    result.MatchStart = 0;
    result.MatchEnd = 0;
    if (nameU8 == NULL || mask == NULL)
        return FALSE;
    BOOL ascii = SalIsASCII(mask) && SalIsASCII(nameU8);
    int end;
    if (ascii || !substring) // the 0.1.10 prefix rule
    {
        if (SalQFDetail::PrefixAt(nameU8, nameU8, hasExtension, mask, ascii, TRUE, end))
        {
            result.Kind = SALQF_PREFIX;
            result.MatchEnd = end;
            return TRUE;
        }
    }
    if (!substring)
        return FALSE;
    if (ascii) // byte-wise, as the prefix rule
    {
        const char* p = nameU8;
        while (*p != 0)
        {
            p++;
            if (*p == 0)
                break;
            if (SalQFDetail::AsciiAux(p, hasExtension, nameU8, mask, FALSE, end))
            {
                result.Kind = SALQF_SUBSTRING;
                result.MatchStart = (int)(p - nameU8);
                result.MatchEnd = end;
                return TRUE;
            }
        }
        return FALSE;
    }
    CSalQFKey ownName;
    CSalQFMaskKeys* ownMask = NULL;
    ownName.Block = NULL;
    if (nameKey == NULL)
    {
        if (!SalQFBuildKey(nameU8, -1, ownName))
            return FALSE;
        nameKey = &ownName;
    }
    if (maskKeys == NULL)
    {
        ownMask = (CSalQFMaskKeys*)malloc(sizeof(CSalQFMaskKeys));
        if (ownMask == NULL || !SalQFBuildMaskKeys(mask, *ownMask))
        {
            if (ownMask != NULL)
                free(ownMask);
            SalQFFreeKey(ownName);
            return FALSE;
        }
        maskKeys = ownMask;
    }
    BOOL found = SalQFMatchKeys(*nameKey, hasExtension, *maskKeys, result);
    if (ownMask != NULL)
    {
        SalQFFreeMaskKeys(*ownMask);
        free(ownMask);
    }
    SalQFFreeKey(ownName);
    return found;
}

// Where the focus goes: 'kinds' holds SALQF_* per item (NONE = no match),
// 'current' the focused index. A prefix match wins: the current item if it is
// one, else the first one below, else the nearest one above; then the same for
// substring matches. Returns -1 when nothing matches.
inline int SalQFChooseFocus(const BYTE* kinds, int count, int current)
{
    if (kinds == NULL || count <= 0)
        return -1;
    if (current < 0)
        current = 0;
    if (current >= count)
        current = count - 1;
    for (int kind = SALQF_PREFIX; kind >= SALQF_SUBSTRING; kind--)
    {
        if (kinds[current] == kind)
            return current;
        for (int i = current + 1; i < count; i++)
            if (kinds[i] == kind)
                return i;
        for (int i = current - 1; i >= 0; i--)
            if (kinds[i] == kind)
                return i;
    }
    return -1;
}

namespace SalQFDetail
{
    // is 't' an acceptable tint: visibly different from the normal background and from
    // every colour in 'avoid' (focused, selected, full-row backgrounds), and the normal
    // text keeps its contrast (4.5:1, or the scheme's own if that is lower, minus 0.25)
    inline BOOL TintOk(COLORREF t, COLORREF normalBk, COLORREF normalFg, const COLORREF* avoid, int avoidCount)
    {
        if (SalQFDistance(t, normalBk) < SALQF_TINT_MIN_DISTANCE)
            return FALSE;
        for (int i = 0; i < avoidCount; i++)
            if (avoid[i] != normalBk && SalQFDistance(t, avoid[i]) < SALQF_TINT_MIN_DISTANCE)
                return FALSE;
        double own = SalQFContrast(normalFg, normalBk);
        double need = (own < 4.5 ? own : 4.5) - 0.25;
        return SalQFContrast(normalFg, t) >= need;
    }
    // the smallest share of 'accent' (10 % .. 40 % in steps of 5) giving an acceptable tint
    inline BOOL TintToward(COLORREF normalBk, COLORREF accent, COLORREF normalFg, const COLORREF* avoid,
                           int avoidCount, COLORREF& tint)
    {
        for (int p = 10; p <= 40; p += 5)
        {
            COLORREF t = Mix(normalBk, accent, p);
            if (TintOk(t, normalBk, normalFg, avoid, avoidCount))
            {
                tint = t;
                return TRUE;
            }
        }
        return FALSE;
    }
} // namespace SalQFDetail

// The background of a searching panel: the normal background with the
// smallest share (10 % .. 40 %) of the panel caption colour 'accentBk' that is
// visibly different from the normal background and from the colours in
// 'avoid' (the focused, selected and full-row backgrounds) and keeps the
// normal text readable. When the caption colour cannot give such a tint (a
// scheme whose caption equals its background), a blue of the brightness
// opposite to the background is used the same way. When nothing qualifies (a
// scheme whose text barely contrasts with its background), the visible
// candidate that keeps the most text contrast - a tint that cannot be seen is
// no indication at all.
inline COLORREF SalQFTint(COLORREF normalBk, COLORREF accentBk, COLORREF normalFg, const COLORREF* avoid,
                          int avoidCount)
{
    COLORREF t;
    if (SalQFDetail::TintToward(normalBk, accentBk, normalFg, avoid, avoidCount, t))
        return t;
    COLORREF blue = SalQFDetail::Luminance(normalBk) > 0.3 ? RGB(0, 90, 200) : RGB(90, 160, 255);
    if (SalQFDetail::TintToward(normalBk, blue, normalFg, avoid, avoidCount, t))
        return t;
    COLORREF white = RGB(255, 255, 255), black = RGB(0, 0, 0);
    COLORREF towards[4] = {accentBk, blue, white, black};
    COLORREF best = SalQFDetail::Mix(normalBk, accentBk, 25);
    double bestContrast = -1;
    for (int a = 0; a < 4; a++)
    {
        for (int p = 10; p <= 40; p += 5)
        {
            COLORREF c = SalQFDetail::Mix(normalBk, towards[a], p);
            if (SalQFDistance(c, normalBk) < SALQF_TINT_MIN_DISTANCE)
                continue;
            double contrast = SalQFContrast(normalFg, c);
            if (contrast > bestContrast)
            {
                bestContrast = contrast;
                best = c;
            }
        }
    }
    return best;
}
