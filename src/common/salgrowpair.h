// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salgrowpair.h
//
// Growing two parallel buffers without losing either (feature 293).
// Header-only, no globals; saltests checks it with a failing allocator;
// CStatusWindow::SetText (src/stswnd.cpp) grows its Text / AlpDX pair with it.
//
// A realloc that succeeds may release the old block - from then on only the
// returned pointer is valid; a realloc that fails leaves its block untouched.
// The panel's directory / information line used to store the two results only
// when both succeeded, so a moved first block followed by a failed second call
// (or the reverse) left the window holding a released block. Here each
// successful result is stored at once and the capacity rises only when both
// buffers hold the new size, so it never exceeds either real size.
//
// A buffer that had no block (NULL) gets nothing from a failed growth: its fresh
// block is uninitialized (a text without a terminator), so it is released again
// and the pointer stays NULL - a fresh owner stays exactly as it was.
//
//*****************************************************************************

#include <stdlib.h>

// grows 'a' and 'b' to 'needed' elements each when 'allocated' is smaller;
// 'reallocFn(block, bytes)' and 'freeFn(block)' behave as the CRT realloc / free;
// TRUE = both hold 'needed' elements and 'allocated' == 'needed'; FALSE = out of
// memory: both pointers are valid (moved blocks keep the old contents), 'allocated'
// is unchanged and still the capacity of both
template <class A, class B, class ReallocFn, class FreeFn>
inline bool SalGrowBufferPair(A*& a, B*& b, int& allocated, int needed, ReallocFn reallocFn, FreeFn freeFn)
{
    if (allocated >= needed)
        return true;
    bool hadA = a != NULL;
    bool hadB = b != NULL;
    A* newA = (A*)reallocFn(a, (size_t)needed * sizeof(A));
    if (newA != NULL)
        a = newA; // at once: the old block may be gone
    B* newB = (B*)reallocFn(b, (size_t)needed * sizeof(B));
    if (newB != NULL)
        b = newB;
    if (newA == NULL || newB == NULL)
    {
        if (newA != NULL && !hadA)
        {
            freeFn(a); // a fresh block holds nothing - the owner stays without one
            a = NULL;
        }
        if (newB != NULL && !hadB)
        {
            freeFn(b);
            b = NULL;
        }
        return false;
    }
    allocated = needed;
    return true;
}

// the same with the CRT realloc / free
template <class A, class B>
inline bool SalGrowBufferPair(A*& a, B*& b, int& allocated, int needed)
{
    return SalGrowBufferPair(
        a, b, allocated, needed, [](void* block, size_t bytes) { return realloc(block, bytes); },
        [](void* block) { free(block); });
}
