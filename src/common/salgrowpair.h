// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salgrowpair.h
//
// Growing parallel buffers without losing any of them (features 293, 295).
// Header-only, no globals; saltests checks it with a failing allocator;
// CStatusWindow::SetText (src/stswnd.cpp) grows its Text / AlpDX pair with it,
// CStaticText::SetText (src/gui.cpp) its Text / TextW (+ AlpDX / Text2 / Text2W).
//
// A realloc that succeeds may release the old block - from then on only the
// returned pointer is valid; a realloc that fails leaves its block untouched.
// The panel's directory / information line used to store the two results only
// when both succeeded, so a moved first block followed by a failed second call
// (or the reverse) left the window holding a released block; a dialog's static
// text released the earlier results when a later call failed, one of them the
// block it still referred to. Here every growth is attempted in order, each
// successful result is stored at once and the capacity rises only when all
// buffers hold the new size, so it never exceeds any real size.
//
// A buffer that had no block (NULL) gets nothing from a failed growth: its fresh
// block is uninitialized (a text without a terminator), so it is released again
// and the pointer stays NULL - a fresh owner stays exactly as it was.
//
//*****************************************************************************

#include <stdlib.h>

// one buffer of a set grown together: 'Ptr' holds 'allocated + Extra' elements
// ('Extra' = room beyond the shared capacity, e.g. 3 for an appended "...")
template <class T>
struct CSalGrowBuffer
{
    T*& Ptr;
    int Extra;
};

template <class T>
inline CSalGrowBuffer<T> SalGrowBuf(T*& ptr, int extra = 0)
{
    return CSalGrowBuffer<T>{ptr, extra};
}

// grows one buffer of the set to 'needed + Extra' elements; TRUE = grown and stored
template <class T, class ReallocFn>
inline bool SalGrowOneBuffer(CSalGrowBuffer<T>& buf, int needed, ReallocFn& reallocFn)
{
    T* grown = (T*)reallocFn(buf.Ptr, (size_t)(needed + buf.Extra) * sizeof(T));
    if (grown == NULL)
        return false;
    buf.Ptr = grown; // at once: the old block may be gone
    return true;
}

// after a failed growth: a block obtained for a buffer that had none holds nothing -
// the owner stays without one
template <class T, class FreeFn>
inline void SalDropFreshBuffer(CSalGrowBuffer<T>& buf, bool had, bool grew, FreeFn& freeFn)
{
    if (grew && !had)
    {
        freeFn(buf.Ptr);
        buf.Ptr = NULL;
    }
}

// grows every buffer of 'bufs' to 'needed' (+ its Extra) elements when 'allocated' is
// smaller, in the order given; 'reallocFn(block, bytes)' and 'freeFn(block)' behave as
// the CRT realloc / free; TRUE = all hold the new size and 'allocated' == 'needed';
// FALSE = out of memory: every pointer is valid (moved blocks keep the old contents),
// 'allocated' is unchanged and still the capacity of all
template <class ReallocFn, class FreeFn, class... T>
inline bool SalGrowBuffersWith(ReallocFn reallocFn, FreeFn freeFn, int& allocated, int needed,
                               CSalGrowBuffer<T>... bufs)
{
    static_assert(sizeof...(T) > 0, "no buffer to grow");
    if (allocated >= needed)
        return true;
    const bool had[] = {(bufs.Ptr != NULL)...};
    const bool grew[] = {SalGrowOneBuffer(bufs, needed, reallocFn)...}; // a braced list runs in order
    bool all = true;
    for (bool g : grew)
        all = all && g;
    if (all)
    {
        allocated = needed;
        return true;
    }
    int i = 0;
    ((SalDropFreshBuffer(bufs, had[i], grew[i], freeFn), i++), ...);
    return false;
}

// the same with the CRT realloc / free (inside lambdas: the Debug core maps them to
// the debug heap by macro)
template <class... T>
inline bool SalGrowBuffers(int& allocated, int needed, CSalGrowBuffer<T>... bufs)
{
    return SalGrowBuffersWith([](void* block, size_t bytes)
                              { return realloc(block, bytes); },
                              [](void* block)
                              { free(block); },
                              allocated, needed, bufs...);
}

// grows 'a' and 'b' to 'needed' elements each when 'allocated' is smaller - the
// two-buffer case of SalGrowBuffersWith (feature 293)
template <class A, class B, class ReallocFn, class FreeFn>
inline bool SalGrowBufferPair(A*& a, B*& b, int& allocated, int needed, ReallocFn reallocFn, FreeFn freeFn)
{
    return SalGrowBuffersWith(reallocFn, freeFn, allocated, needed, SalGrowBuf(a), SalGrowBuf(b));
}

// the same with the CRT realloc / free
template <class A, class B>
inline bool SalGrowBufferPair(A*& a, B*& b, int& allocated, int needed)
{
    return SalGrowBuffers(allocated, needed, SalGrowBuf(a), SalGrowBuf(b));
}
