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
// A substring match is the prefix rule applied at the leftmost character
// boundary where it succeeds (an implicit leading wildcard); the dot
// tolerance applies only to prefix matches.
//
//*****************************************************************************

#include <windows.h>
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

namespace SalQFDetail
{
    inline char AsciiLower(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c + ('a' - 'A')) : c; }

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

// Does 'nameU8' match 'mask' (PrepareQSMask output)? 'substring' FALSE = the
// 0.1.10 rule only. Fills 'result' (Kind NONE when it does not match).
inline BOOL SalQFMatchName(const char* nameU8, BOOL hasExtension, const char* mask, BOOL substring,
                           CSalQFMatch& result)
{
    result.Kind = SALQF_NONE;
    result.MatchStart = 0;
    result.MatchEnd = 0;
    if (nameU8 == NULL || mask == NULL)
        return FALSE;
    BOOL ascii = SalIsASCII(mask) && SalIsASCII(nameU8);
    int end;
    if (SalQFDetail::PrefixAt(nameU8, nameU8, hasExtension, mask, ascii, TRUE, end))
    {
        result.Kind = SALQF_PREFIX;
        result.MatchEnd = end;
        return TRUE;
    }
    if (!substring)
        return FALSE;
    const char* p = nameU8;
    while (*p != 0)
    {
        p = ascii ? p + 1 : SalU8Next(p);
        if (*p == 0)
            break;
        if (SalQFDetail::PrefixAt(p, nameU8, hasExtension, mask, ascii, FALSE, end))
        {
            result.Kind = SALQF_SUBSTRING;
            result.MatchStart = (int)(p - nameU8);
            result.MatchEnd = end;
            return TRUE;
        }
    }
    return FALSE;
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
// opposite to the background is used the same way; when nothing qualifies, the
// 25 % mix with the caption colour.
inline COLORREF SalQFTint(COLORREF normalBk, COLORREF accentBk, COLORREF normalFg, const COLORREF* avoid,
                          int avoidCount)
{
    COLORREF t;
    if (SalQFDetail::TintToward(normalBk, accentBk, normalFg, avoid, avoidCount, t))
        return t;
    COLORREF blue = SalQFDetail::Luminance(normalBk) > 0.3 ? RGB(0, 90, 200) : RGB(90, 160, 255);
    if (SalQFDetail::TintToward(normalBk, blue, normalFg, avoid, avoidCount, t))
        return t;
    return SalQFDetail::Mix(normalBk, accentBk, 25);
}
