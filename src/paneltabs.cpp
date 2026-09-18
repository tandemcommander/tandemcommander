// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "cfgdlg.h"
#include "mainwnd.h"
#include "stswnd.h"
#include "plugins.h"
#include "fileswnd.h"
#include "filesbox.h"
#include "tabwnd.h"

//
// ****************************************************************************
// CPanelTab
//

CPanelTab::CPanelTab()
{
    SalTabRecordInit(this);
    PathHistory = new CPathHistory();
    ResetSession();
    Visited = TRUE;
}

CPanelTab::CPanelTab(const CSalTabRecord& rec)
{
    *(CSalTabRecord*)this = rec;
    PathHistory = new CPathHistory();
    ResetSession();
    Visited = TRUE;
}

CPanelTab::~CPanelTab()
{
    if (PathHistory != NULL)
        delete PathHistory;
}

void CPanelTab::ResetSession()
{
    FocusName[0] = 0;
    TopIndex = -1;
    XOffset = 0;
    Selection.Clear();
    TopIndexMem.Clear();
    UserWorkedOnThisPath = FALSE;
}

//
// ****************************************************************************
// CPanelTabs
//

CPanelTabs::CPanelTabs() : Tabs(4, 4)
{
    ActiveIndex = 0;
    ContextTabIndex = -1;
    SwitchInProgress = FALSE;
}

CPanelTabs::~CPanelTabs()
{
}

CPanelTab* CPanelTabs::Add(const CSalTabRecord& rec, int afterIndex)
{
    CPanelTab* tab = new CPanelTab(rec);
    if (tab == NULL || tab->PathHistory == NULL)
    {
        TRACE_E(LOW_MEMORY);
        if (tab != NULL)
            delete tab;
        return NULL;
    }
    int index = (afterIndex < 0 || afterIndex >= Tabs.Count) ? Tabs.Count : afterIndex + 1;
    Tabs.Insert(index, tab);
    if (!Tabs.IsGood())
    {
        Tabs.ResetState();
        delete tab;
        return NULL;
    }
    if (index <= ActiveIndex && Tabs.Count > 1)
        ActiveIndex++;
    return tab;
}

void CPanelTabs::Remove(int index)
{
    if (index < 0 || index >= Tabs.Count)
        return;
    int newActive = SalTabsIndexAfterClose(Tabs.Count, index, ActiveIndex);
    Tabs.Delete(index); // deletes the tab (dtDelete) and its history
    if (!Tabs.IsGood())
        Tabs.ResetState();
    ActiveIndex = newActive;
    if (ActiveIndex >= Tabs.Count)
        ActiveIndex = Tabs.Count - 1;
    if (ActiveIndex < 0)
        ActiveIndex = 0;
    ContextTabIndex = -1;
}

void CPanelTabs::Move(int from, int to)
{
    if (from < 0 || from >= Tabs.Count || to < 0 || to >= Tabs.Count || from == to)
        return;
    CPanelTab* tab = Tabs[from];
    Tabs.Detach(from);
    Tabs.Insert(to, tab);
    if (!Tabs.IsGood())
        Tabs.ResetState();
    SalTabsMove(Tabs.Count, from, to, &ActiveIndex);
}

//
// ****************************************************************************
// CFilesWindow - tab operations
//

int CFilesWindow::GetTabStripHeight()
{
    if (TabStrip != NULL && TabStrip->HWindow != NULL)
        return TabStrip->GetNeededHeight();
    return 0;
}

void CFilesWindow::UpdateTabStrip()
{
    if (TabStrip != NULL && TabStrip->HWindow != NULL)
        TabStrip->InvalidateAndUpdate(FALSE);
}

void CFilesWindow::ToggleTabStrip()
{
    CALL_STACK_MESSAGE1("CFilesWindow::ToggleTabStrip()");
    if (HWindow == NULL || TabStrip == NULL)
    {
        TRACE_E("CFilesWindow::ToggleTabStrip(): no window");
        return;
    }
    if (TabStrip->HWindow != NULL) // turn off
    {
        DestroyWindow(TabStrip->HWindow);
    }
    else // turn on: created hidden, shown after the panel has laid it out
    {
        if (!TabStrip->Create(CWINDOW_CLASSNAME2,
                              "",
                              WS_CHILD | WS_CLIPSIBLINGS,
                              0, 0, 0, 0,
                              HWindow,
                              (HMENU)IDC_TABSTRIP,
                              HInstance,
                              TabStrip))
            TRACE_E("Unable to create the tab strip.");
    }
    InvalidateRect(HWindow, NULL, TRUE);
    RECT r;
    GetClientRect(HWindow, &r);
    SendMessage(HWindow, WM_SIZE, SIZE_RESTORED,
                MAKELONG(r.right - r.left, r.bottom - r.top));
    if (TabStrip->HWindow != NULL)
        ShowWindow(TabStrip->HWindow, SW_SHOW);
    // the middle toolbar and the popup anchors depend on the chrome height
    if (MainWindow != NULL && MainWindow->HWindow != NULL)
        MainWindow->LayoutWindows();
}

void CFilesWindow::CaptureActiveTab()
{
    CALL_STACK_MESSAGE1("CFilesWindow::CaptureActiveTab()");
    CPanelTab* tab = Tabs.Active();
    if (tab == NULL)
        return;

    GetGeneralPath(tab->Location, SAL_TAB_LOCATION_MAX, TRUE);
    tab->ViewTemplateIndex = GetViewTemplateIndex();
    tab->SortType = SortType;
    tab->ReverseSort = ReverseSort;
    lstrcpyn(tab->FilterMasks, Filter.GetMasksString(), SAL_TAB_FILTER_MAX);
    tab->FilterEnabled = FilterEnabled;

    tab->FocusName[0] = 0;
    tab->TopIndex = -1;
    tab->XOffset = 0;
    tab->Selection.Clear();
    if (ListBox != NULL && ListBox->HWindow != NULL && Files != NULL && Dirs != NULL)
    {
        int total = Files->Count + Dirs->Count;
        int index = GetCaretIndex();
        if (index >= 0 && index < total)
        {
            CFileData* f = (index < Dirs->Count) ? &Dirs->At(index) : &Files->At(index - Dirs->Count);
            lstrcpyn(tab->FocusName, f->Name, SAL_FIND_NAME_U8);
        }
        tab->TopIndex = ListBox->GetTopIndex();
        if (GetViewMode() == vmDetailed)
            tab->XOffset = ListBox->GetXOffset();
        if (GetSelCount() > 0)
        {
            tab->Selection.SetCaseSensitive(IsCaseSensitive());
            int i;
            for (i = 0; i < total; i++)
            {
                BOOL isDir = i < Dirs->Count;
                CFileData* f = isDir ? &Dirs->At(i) : &Files->At(i - Dirs->Count);
                if (f->Selected && !tab->Selection.Add(isDir, f->Name))
                    break; // low memory
            }
            tab->Selection.Sort();
        }
    }
    tab->TopIndexMem = TopIndexMem;
    tab->UserWorkedOnThisPath = UserWorkedOnThisPath;
    if (tab->PathHistory != PathHistory)
        TRACE_E("CFilesWindow::CaptureActiveTab(): the panel history is not the active tab's");
    tab->Visited = TRUE;
}

BOOL CFilesWindow::SwitchToTab(int target)
{
    CALL_STACK_MESSAGE2("CFilesWindow::SwitchToTab(%d)", target);
    if (!Configuration.PanelTabs)
        return FALSE;
    if (target < 0 || target >= Tabs.Count() || target == Tabs.ActiveIndex)
        return FALSE;
    if (Tabs.SwitchInProgress || FilesActionInProgress ||
        (MainWindow != NULL && MainWindow->HasLockedUI()))
        return FALSE;
    if (PathHistory != NULL && PathHistory->IsLocked()) // a Back/Forward navigation is running
        return FALSE;
    CPanelTab* cur = Tabs.Active();
    CPanelTab* tab = Tabs.At(target);
    if (cur == NULL || tab == NULL || tab->Location[0] == 0 || tab->PathHistory == NULL)
        return FALSE;

    Tabs.SwitchInProgress = TRUE;
    CancelUI();              // quick search / quick rename, as any path change does
    RefreshPathHistoryData(); // the leaving cursor into the leaving tab's history
    CaptureActiveTab();

    // what a refused leave has to put back
    CSortType oldSort = SortType;
    BOOL oldReverse = ReverseSort;
    CMaskGroup oldFilter;
    oldFilter = Filter;
    BOOL oldFilterEnabled = FilterEnabled;
    int oldView = GetViewTemplateIndex();
    CPathHistory* oldHistory = PathHistory;

    // pre-set what the new listing must be read with (nothing visible changes yet)
    SortType = (CSortType)tab->SortType;
    ReverseSort = tab->ReverseSort;
    Filter.SetMasksString(tab->FilterMasks[0] != 0 ? tab->FilterMasks : "*.*");
    int errPos;
    if (!Filter.PrepareMasks(errPos))
    {
        Filter.SetMasksString("*.*");
        Filter.PrepareMasks(errPos);
    }
    FilterEnabled = tab->FilterEnabled;
    BOOL viewChanged = FALSE;
    if (tab->ViewTemplateIndex != oldView && IsViewTemplateValid(tab->ViewTemplateIndex))
    {
        SelectViewTemplate(tab->ViewTemplateIndex, FALSE, FALSE, VALID_DATA_ALL, FALSE, TRUE);
        viewChanged = TRUE;
    }
    // the new location is appended to the target tab's history by DirectoryLineSetText
    PathHistory = tab->PathHistory;

    int failReason = CHPPFR_SUCCESS;
    BOOL ok = ChangeDir(tab->Location, tab->TopIndex, tab->FocusName[0] != 0 ? tab->FocusName : NULL,
                        3 /*change-dir*/, &failReason, TRUE /*external -> internal FS path*/);
    if (!ok && failReason == CHPPFR_CANNOTCLOSEPATH)
    {
        // the plugin refused or the user cancelled: the panel is intact, put the rest back
        SortType = oldSort;
        ReverseSort = oldReverse;
        Filter = oldFilter;
        Filter.PrepareMasks(errPos);
        FilterEnabled = oldFilterEnabled;
        PathHistory = oldHistory;
        if (viewChanged)
            SelectViewTemplate(oldView, FALSE, FALSE, VALID_DATA_ALL, TRUE, TRUE);
        UpdateFilterSymbol();
        DirectoryLineSetText();
        int t1 = MyTimeCounter++; // icons may have gone "temporarily simple"
        PostMessage(HWindow, WM_USER_REFRESH_DIR, 0, t1);
        Tabs.SwitchInProgress = FALSE;
        UpdateTabStrip();
        return FALSE;
    }

    // the panel shows the target (or, when the location was gone, its fallback)
    TopIndexMem = tab->TopIndexMem; // ChangeDir cleared the panel's ("long jump")
    if (tab->Selection.GetCount() > 0 && Files != NULL && Dirs != NULL)
    {
        int total = Files->Count + Dirs->Count;
        int i;
        for (i = 0; i < total; i++)
        {
            BOOL isDir = i < Dirs->Count;
            CFileData* f = isDir ? &Dirs->At(i) : &Files->At(i - Dirs->Count);
            if (tab->Selection.Contains(isDir, f->Name))
                SetSel(TRUE, f);
        }
        RepaintListBox(DRAWFLAG_DIRTY_ONLY | DRAWFLAG_SKIP_VISTEST);
        PostMessage(HWindow, WM_USER_SELCHANGED, 0, 0);
    }
    if (tab->XOffset != 0 && GetViewMode() == vmDetailed && ListBox != NULL)
        RefreshListBox(tab->XOffset, ListBox->GetTopIndex(), FocusedIndex, FALSE, FALSE);
    UserWorkedOnThisPath = tab->UserWorkedOnThisPath;
    Tabs.ActiveIndex = target;
    tab->Visited = TRUE;
    if (!ok) // fell back to a shorter path / the rescue path: remember where we really are
        GetGeneralPath(tab->Location, SAL_TAB_LOCATION_MAX, TRUE);
    IdleRefreshStates = TRUE; // Back/Forward enablers now read the target tab's history
    Tabs.SwitchInProgress = FALSE;
    UpdateTabStrip();
    return TRUE;
}

void CFilesWindow::NewTab()
{
    CALL_STACK_MESSAGE1("CFilesWindow::NewTab()");
    if (!Configuration.PanelTabs)
        return;
    CaptureActiveTab();
    CPanelTab* cur = Tabs.Active();
    CSalTabRecord rec;
    SalTabRecordInit(&rec);
    if (cur != NULL)
        rec = *(const CSalTabRecord*)cur;
    if (rec.Location[0] == 0)
        return;
    int newIndex = Tabs.Count();
    if (Tabs.Add(rec, -1) == NULL)
        return;
    if (!SwitchToTab(newIndex))
        Tabs.Remove(newIndex);
    UpdateTabStrip();
}

void CFilesWindow::DuplicateTab(int index)
{
    CALL_STACK_MESSAGE2("CFilesWindow::DuplicateTab(%d)", index);
    if (!Configuration.PanelTabs)
        return;
    if (index == Tabs.ActiveIndex)
        CaptureActiveTab();
    CPanelTab* src = Tabs.At(index);
    if (src == NULL || src->Location[0] == 0)
        return;
    CSalTabRecord rec = *(const CSalTabRecord*)src;
    if (Tabs.Add(rec, index) == NULL)
        return;
    if (!SwitchToTab(index + 1))
        Tabs.Remove(index + 1);
    UpdateTabStrip();
}

BOOL CFilesWindow::CloseTab(int index)
{
    CALL_STACK_MESSAGE2("CFilesWindow::CloseTab(%d)", index);
    if (!Configuration.PanelTabs || Tabs.Count() <= 1 || Tabs.At(index) == NULL)
        return FALSE;
    if (index == Tabs.ActiveIndex)
    {
        int neighbour = (index < Tabs.Count() - 1) ? index + 1 : index - 1;
        if (!SwitchToTab(neighbour))
            return FALSE; // leaving was refused - the tab stays
    }
    Tabs.Remove(index);
    UpdateTabStrip();
    return TRUE;
}

void CFilesWindow::CloseOtherTabs(int keepIndex)
{
    CALL_STACK_MESSAGE2("CFilesWindow::CloseOtherTabs(%d)", keepIndex);
    if (!Configuration.PanelTabs || Tabs.At(keepIndex) == NULL)
        return;
    if (keepIndex != Tabs.ActiveIndex && !SwitchToTab(keepIndex))
        return;
    int i;
    for (i = Tabs.Count() - 1; i >= 0; i--)
        if (i != Tabs.ActiveIndex)
            Tabs.Remove(i);
    UpdateTabStrip();
}

void CFilesWindow::CloseTabsToRight(int index)
{
    CALL_STACK_MESSAGE2("CFilesWindow::CloseTabsToRight(%d)", index);
    if (!Configuration.PanelTabs || Tabs.At(index) == NULL)
        return;
    if (Tabs.ActiveIndex > index && !SwitchToTab(index))
        return;
    int i;
    for (i = Tabs.Count() - 1; i > index; i--)
        Tabs.Remove(i);
    UpdateTabStrip();
}

void CFilesWindow::MoveTab(int from, int to)
{
    CALL_STACK_MESSAGE3("CFilesWindow::MoveTab(%d, %d)", from, to);
    if (!Configuration.PanelTabs)
        return;
    Tabs.Move(from, to);
    UpdateTabStrip();
}

void CFilesWindow::SetTabsEnabled(BOOL on)
{
    CALL_STACK_MESSAGE2("CFilesWindow::SetTabsEnabled(%d)", on);
    if (Tabs.Count() == 0) // cannot happen (the constructor adds the first tab); be safe
    {
        CSalTabRecord rec;
        SalTabRecordInit(&rec);
        CPanelTab* tab = Tabs.Add(rec, -1);
        if (tab == NULL)
            return;
        Tabs.ActiveIndex = 0;
        PathHistory = tab->PathHistory;
    }
    if (on)
    {
        CaptureActiveTab();
        if (TabStrip != NULL && TabStrip->HWindow == NULL && HWindow != NULL)
            ToggleTabStrip();
        else
            UpdateTabStrip();
    }
    else
    {
        // only the active tab survives; background tabs held nothing open
        int i;
        for (i = Tabs.Count() - 1; i >= 0; i--)
            if (i != Tabs.ActiveIndex)
                Tabs.Remove(i);
        Tabs.ActiveIndex = 0;
        if (TabStrip != NULL && TabStrip->HWindow != NULL)
            ToggleTabStrip();
    }
}
