// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salumbalance.h
//
// Feature 268: what the start-up loader of the User Menu does with each entry
// so that skipping a damaged entry never unbalances the submenus - a pure rule,
// so saltests can check it.
//
// The loader skips an entry whose required values (name, command, "execute
// through shell", "close shell window") cannot be read, and goes on with the
// next one. When the skipped entry began a submenu, its end would be left
// without a beginning: the menu stops at such an end (every later item is
// hidden from the menu and the User Menu toolbar), and the configuration page
// cannot delete an end. So:
//   - a damaged submenu beginning is skipped together with its matching end -
//     the items between them move one level up, none is lost;
//   - a damaged submenu end is loaded as a plain end (an end's name and command
//     are never used) - the submenu stays closed where the user closed it.
// Intact entries load as read, including an end the user's own list has without
// a beginning (the rule does not repair what it did not cause). A damaged entry
// of another kind, or whose type cannot be read, is just skipped.
//
// Header-only: the core loader and saltests share it.
//
//*****************************************************************************

enum CSalUMEntryKind
{
    SALUM_ITEM,          // an intact item or separator
    SALUM_BEGIN,         // an intact submenu beginning
    SALUM_END,           // an intact submenu end
    SALUM_DAMAGED,       // a damaged entry that is not a submenu beginning or end (or of unknown type)
    SALUM_DAMAGED_BEGIN, // a damaged entry whose type says submenu beginning
    SALUM_DAMAGED_END,   // a damaged entry whose type says submenu end
};

enum CSalUMEntryAction
{
    SALUM_LOAD,        // add the entry as read
    SALUM_LOAD_AS_END, // add a plain submenu end in its place
    SALUM_SKIP,        // leave the entry out
};

class CSalUMSubmenuBalance
{
public:
    enum
    {
        MAX_TRACKED = 256 // deeper levels are not tracked: a damaged beginning there is skipped, its end stays
    };

protected:
    bool SkippedBegin[MAX_TRACKED]; // per open level: its beginning was a skipped damaged entry
    int Depth;                      // open levels (may exceed MAX_TRACKED)

    void Push(bool skipped)
    {
        if (Depth < MAX_TRACKED)
            SkippedBegin[Depth] = skipped;
        Depth++;
    }
    // closes the innermost open level; returns whether its beginning was skipped
    bool Pop()
    {
        Depth--;
        return Depth < MAX_TRACKED && SkippedBegin[Depth];
    }

public:
    CSalUMSubmenuBalance() { Depth = 0; }

    // the next entry of the list, in order
    CSalUMEntryAction Next(CSalUMEntryKind kind)
    {
        switch (kind)
        {
        case SALUM_BEGIN:
            Push(false);
            return SALUM_LOAD;

        case SALUM_END:
            if (Depth == 0)
                return SALUM_LOAD; // the user's own stray end: as read
            return Pop() ? SALUM_SKIP : SALUM_LOAD;

        case SALUM_DAMAGED_BEGIN:
            Push(true);
            return SALUM_SKIP;

        case SALUM_DAMAGED_END:
            if (Depth == 0)
                return SALUM_SKIP; // nothing open: a stray end that is damaged too
            return Pop() ? SALUM_SKIP : SALUM_LOAD_AS_END;

        case SALUM_DAMAGED:
            return SALUM_SKIP;

        default: // SALUM_ITEM
            return SALUM_LOAD;
        }
    }
};
