// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// feature 143: the loops a map window's thread can be inside of (its popup menus, its own
// boxes, shell commands). A close request that arrives inside one must not destroy the window
// there - the code that opened the loop would run on into freed objects (0.1.10 crashed on exit
// with the context menu or the shell's Delete confirmation open). The rule is in
// src/common/salloopclose.h; the map window (CMainWindow) is the owner that counts.

#include "../../../common/salloopclose.h"

class CMapLoopOwner
{
public:
    virtual void LoopEnter(CSalLoopKind kind) = 0;
    virtual void LoopLeave(CSalLoopKind kind) = 0;
};

// counts one loop for as long as it lives; 'owner' NULL counts nothing
class CMapLoopScope
{
    CMapLoopOwner* _owner;
    CSalLoopKind _kind;

public:
    CMapLoopScope(CMapLoopOwner* owner, CSalLoopKind kind)
    {
        this->_owner = owner;
        this->_kind = kind;
        if (this->_owner != NULL)
            this->_owner->LoopEnter(kind);
    }
    ~CMapLoopScope()
    {
        if (this->_owner != NULL)
            this->_owner->LoopLeave(this->_kind);
    }

private:
    CMapLoopScope(const CMapLoopScope&);
    CMapLoopScope& operator=(const CMapLoopScope&);
};
