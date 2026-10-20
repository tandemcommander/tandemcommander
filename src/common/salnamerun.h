// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salnamerun.h
//
// Which of the dragged / pasted names a listed name is (feature 230). Core only
// (it calls SalNameCompareOrdinalCI of salunicode.cpp; plug-ins have
// salnameorder.h); saltests checks it.
//
// DragDropToArcOrFS matches the source folder's listing against the names of
// the data object, sorted by SalNameCompareOrdinalCI. In a case-sensitive folder
// (WSL, setCaseSensitiveInfo) "a.txt" and "A.txt" are two files that compare
// equal: before feature 230 the second one listed was taken as a "duplicate" and
// added anyway - an item nobody selected was packed (and with Move deleted), and
// the index array sized by the names was overrun. Now each name is taken once:
//   1. by the listed item byte-equal to it;
//   2. only when none is: by the one listed item equal to it case-insensitively
//      - the drag source may give a name in another case than the disk lists it
//      (a path the user typed) - provided the name's case-insensitive run holds
//      that name alone (SalNameCIRunSingle) and the folder is not case-sensitive
//      (decided by the caller after the listing).
//
//*****************************************************************************

#include <windows.h>
#include <string.h>
#include "salunicode.h"

// 'names' (count entries, sorted with SalNameCompareOrdinalCI), 'ciIndex' an index ContainsString
// found for 'name' (a case-insensitive match). Returns the index of the byte-equal entry within the
// run of entries equal to 'name' case-insensitively, or -1 when none is byte-equal.
inline int SalNameExactInCIRun(char* const* names, int count, int ciIndex, const char* name)
{
    if (ciIndex < 0 || ciIndex >= count)
        return -1;
    int lo = ciIndex;
    while (lo > 0 && SalNameCompareOrdinalCI(names[lo - 1], -1, name, -1) == 0)
        lo--;
    for (int i = lo; i < count && SalNameCompareOrdinalCI(names[i], -1, name, -1) == 0; i++)
    {
        if (strcmp(names[i], name) == 0)
            return i;
    }
    return -1;
}

// the index of 'names' (as above) that the case-insensitive run around 'ciIndex' consists of alone,
// or -1 when the run holds more entries (then a listed name in another case cannot tell which one)
inline int SalNameCIRunSingle(char* const* names, int count, int ciIndex)
{
    if (ciIndex < 0 || ciIndex >= count)
        return -1;
    const char* n = names[ciIndex];
    if (ciIndex > 0 && SalNameCompareOrdinalCI(names[ciIndex - 1], -1, n, -1) == 0)
        return -1;
    if (ciIndex + 1 < count && SalNameCompareOrdinalCI(names[ciIndex + 1], -1, n, -1) == 0)
        return -1;
    return ciIndex;
}

// after the listing: does the one item equal to a name only case-insensitively take it? Only when no
// byte-equal item took the name, exactly one such item was listed and the folder is not
// case-sensitive (there "A.txt" is another file than a dragged "a.txt")
inline BOOL SalNameCIFallbackTakes(BOOL nameTaken, int ciOnlyCount, BOOL dirCaseSensitive)
{
    return !nameTaken && ciOnlyCount == 1 && !dirCaseSensitive;
}

//*****************************************************************************
//
// Feature 261: lookups and Compare Directories in folders with case twins
//
// A case-sensitive folder can hold "a.txt" and "A.txt" (twins: byte-different,
// the same name by SalNameEqualOrdinalCI). The viewer's next / previous file, the
// User Menu's second compare name and Ctrl+X ghosting in the other panel took the
// first name equal ignoring case; Compare Directories paired a.txt with the other
// side's A.txt. Now:
//   - a lookup takes the byte-identical item, else the one item equal ignoring
//     case when it is the only one (a name changed in case only is still found),
//     never one of two (SalNamePickIndex);
//   - Compare Directories pairs a run of names with one case-insensitive sort
//     key on both sides as a set when either run holds twins
//     (SalHasCaseTwinInRun): byte-identical names first, then a name without a
//     twin with the one name of the other side equal to it ignoring case that
//     has no twin either (feature 232: a case-only pair is one name); a twin is
//     never paired with another case (SalTwinRunPairs). The run is then walked
//     pairs first (SalTwinRunOrder, SalTwinRunSlotCmp) - a comparison switched
//     pair by pair between the exact and the case-insensitive order is not
//     consistent with the lists' sort order (the locale key ignores a soft
//     hyphen, NFC / NFD) and stepped past a partner (review of 261).
//
//*****************************************************************************

// the index of the candidate a lookup of 'name' takes: the first byte-identical one, else the only
// one equal by SalNameEqualOrdinalCI, else -1 (none, or two or more - which one is meant cannot be
// told). nameAt(i, &n, &len) gives candidate i (len < 0 = up to the terminator); 'nameLen' < 0 = up
// to the terminator.
template <class TNameAt>
int SalNamePickIndex(int count, const char* name, int nameLen, TNameAt nameAt)
{
    if (name == NULL)
        return -1;
    if (nameLen < 0)
        nameLen = (int)strlen(name);
    int ciIndex = -1;
    int ciCount = 0;
    for (int i = 0; i < count; i++)
    {
        const char* n = NULL;
        int len = -1;
        nameAt(i, &n, &len);
        if (n == NULL)
            continue;
        if (len < 0)
            len = (int)strlen(n);
        if (len == nameLen && memcmp(n, name, (size_t)len) == 0)
            return i;
        if (SalNameEqualOrdinalCI(n, len, name, nameLen))
        {
            if (ciCount++ == 0)
                ciIndex = i;
        }
    }
    return ciCount == 1 ? ciIndex : -1;
}

// TRUE when item 'index' of a list sorted by a case-insensitive first key has a twin: a neighbour
// with the same first key (sameKey(index, k)) that isTwin(index, k) - byte-different and the same
// name ignoring case. Twins share the first key, so they sit in one run of neighbours.
template <class TSameKey, class TIsTwin>
BOOL SalHasCaseTwinInRun(int count, int index, TSameKey sameKey, TIsTwin isTwin)
{
    if (index < 0 || index >= count)
        return FALSE;
    for (int k = index - 1; k >= 0 && sameKey(index, k); k--)
    {
        if (isTwin(index, k))
            return TRUE;
    }
    for (int k = index + 1; k < count && sameKey(index, k); k++)
    {
        if (isTwin(index, k))
            return TRUE;
    }
    return FALSE;
}

// pairs a run pair of Compare Directories (nL names on the left, nR on the right, one first sort
// key): first byte-identical names (exact(i, j)), then a left name without a twin in its list
// (!leftTwin(i)) with a right name without one (!rightTwin(j)) that is the same name ignoring case
// (sameName(i, j)); a twin is never paired with another case - which one is meant cannot be told.
// leftPartner[i] / rightPartner[j]: the partner's index in the other run, or -1. Returns the number
// of pairs.
template <class TExact, class TSameName, class TLeftTwin, class TRightTwin>
int SalTwinRunPairs(int nL, int nR, TExact exact, TSameName sameName, TLeftTwin leftTwin, TRightTwin rightTwin,
                    int* leftPartner, int* rightPartner)
{
    for (int i = 0; i < nL; i++)
        leftPartner[i] = -1;
    for (int j = 0; j < nR; j++)
        rightPartner[j] = -1;
    int pairs = 0;
    for (int i = 0; i < nL; i++)
    {
        for (int j = 0; j < nR; j++)
        {
            if (rightPartner[j] == -1 && exact(i, j))
            {
                leftPartner[i] = j;
                rightPartner[j] = i;
                pairs++;
                break;
            }
        }
    }
    for (int i = 0; i < nL; i++)
    {
        if (leftPartner[i] != -1 || leftTwin(i))
            continue;
        for (int j = 0; j < nR; j++)
        {
            if (rightPartner[j] == -1 && !rightTwin(j) && sameName(i, j))
            {
                leftPartner[i] = j;
                rightPartner[j] = i;
                pairs++;
                break;
            }
        }
    }
    return pairs;
}

// the order a run pair is walked in: the pairs first (in the left run's order, each right partner at
// the position of its left name), then the unpaired names of each side in their own order.
// orderL[k] / orderR[k]: the run index of the name that goes to position k.
inline void SalTwinRunOrder(int nL, const int* leftPartner, int nR, const int* rightPartner, int* orderL, int* orderR)
{
    int k = 0;
    for (int i = 0; i < nL; i++)
    {
        if (leftPartner[i] != -1)
        {
            orderL[k] = i;
            orderR[k] = leftPartner[i];
            k++;
        }
    }
    int kl = k;
    for (int i = 0; i < nL; i++)
    {
        if (leftPartner[i] == -1)
            orderL[kl++] = i;
    }
    int kr = k;
    for (int j = 0; j < nR; j++)
    {
        if (rightPartner[j] == -1)
            orderR[kr++] = j;
    }
}

// the merge comparison of position il of the left run and ir of the right run walked in
// SalTwinRunOrder's order with 'pairs' pairs: 0 = a pair; an unpaired name on either side sorts after
// the pairs, the left ones before the right ones (each is then reported alone); -1 / 0 / 1
inline int SalTwinRunSlotCmp(int il, int ir, int pairs)
{
    if (il < pairs && ir < pairs)
        return (il > ir) - (il < ir);
    if (il < pairs)
        return -1;
    if (ir < pairs)
        return 1;
    return -1;
}
