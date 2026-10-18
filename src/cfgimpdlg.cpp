// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Feature 245: the settings import wizard (five pages), the one-time offer at
// the first start of a fresh configuration and the Debug-only automation seam.
// See cfgimport.h and specs/245-settings-import-salamander/contracts/wizard-flow.md.

#include "precomp.h"

#include "cfgdlg.h"
#include "mainwnd.h"
#include "plugins.h"
#include "pwdmngr.h"
#include "cfgimport.h"

#define CFGIMP_HELPID IDD_CFGIMPORT_SOURCE // one help page for the whole wizard

//
// ****************************************************************************
// helpers
//

// a multi-line read-only edit gets a (possibly long) UTF-8 text
static void CfgImpSetEditText(HWND edit, const char* text)
{
    SendMessageW(edit, EM_SETLIMITTEXT, 0x7FFFFFFE, 0);
    WCHAR* w = SalU8ToWAlloc(text != NULL ? text : "");
    SetWindowTextW(edit, w != NULL ? w : L"");
    free(w);
}

static void CfgImpMessage(HWND parent, const char* text, UINT flags)
{
    char title[200];
    lstrcpyn(title, LoadStrU8(IDS_CFGIMP_TITLE), (int)sizeof(title));
    SalMessageBox(parent, text, title, flags);
}

// writes a UTF-8 text (with BOM) to a file chosen by the user
static void CfgImpSaveReport(HWND parent, const char* text)
{
    WCHAR file[MAX_PATH] = L"import-report.txt";
    OPENFILENAMEW ofn;
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = parent;
    ofn.lpstrFilter = L"*.txt\0*.txt\0*.*\0*.*\0";
    ofn.lpstrFile = file;
    ofn.nMaxFile = MAX_PATH;
    ofn.lpstrDefExt = L"txt";
    ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY | OFN_NOCHANGEDIR;
    if (!SafeGetSaveFileNameW(&ofn))
        return;
    HANDLE h = CreateFileW(file, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    BOOL ok = h != INVALID_HANDLE_VALUE;
    if (ok)
    {
        DWORD written;
        ok = WriteFile(h, "\xEF\xBB\xBF", 3, &written, NULL) && written == 3;
        DWORD l = (DWORD)strlen(text);
        ok = ok && WriteFile(h, text, l, &written, NULL) && written == l;
        CloseHandle(h);
    }
    if (!ok)
        CfgImpMessage(parent, LoadStrU8(IDS_CFGIMP_SAVEFAILED), MB_OK | MB_ICONEXCLAMATION);
}

#define CFGIMP_RES_BACK 100 // a page closed with "< Back"

//
// ****************************************************************************
// page 1: the source
//

class CCfgImpSourcePage : public CCommonDialog
{
public:
    CCfgImpRun* Run;
    int Selected;

    CCfgImpSourcePage(HWND parent, CCfgImpRun* run, int selected)
        : CCommonDialog(HLanguage, IDD_CFGIMPORT_SOURCE, CFGIMP_HELPID, parent, ooStandard, NULL, TRUE)
    {
        Run = run;
        Selected = selected;
    }

protected:
    void UpdateNote()
    {
        HWND list = GetDlgItem(HWindow, IDC_CFGIMP_SOURCES);
        int sel = (int)SendMessageW(list, LB_GETCURSEL, 0, 0);
        int index = sel != LB_ERR ? (int)SendMessageW(list, LB_GETITEMDATA, sel, 0) : -1;
        BOOL ok = index >= 0 && index < Run->Sources.Count && Run->Sources[index].Support == SALCFGIMP_SUPPORTED;
        EnableWindow(GetDlgItem(HWindow, IDOK), ok);
        char note[1000];
        note[0] = 0;
        if (Run->Sources.Count == 0)
            lstrcpyn(note, LoadStrU8(IDS_CFGIMP_SRC_NONE), (int)sizeof(note));
        else
        {
            if (ok && Run->Sources[index].SaveInProgress)
                lstrcpyn(note, LoadStrU8(IDS_CFGIMP_SRC_SAVEINPROGRESS), (int)sizeof(note));
            if (Run->SourceProgramRuns)
            {
                if (note[0] != 0)
                    strcat_s(note, "\n");
                strncat_s(note, LoadStrU8(IDS_CFGIMP_SRC_RUNNING), _TRUNCATE);
            }
        }
        SalSetDlgItemTextU8(HWindow, IDC_CFGIMP_SRCNOTE, note);
    }

    virtual void Transfer(CTransferInfo& ti)
    {
        if (ti.Type == ttDataFromWindow)
        {
            HWND list = GetDlgItem(HWindow, IDC_CFGIMP_SOURCES);
            int sel = (int)SendMessageW(list, LB_GETCURSEL, 0, 0);
            Selected = sel != LB_ERR ? (int)SendMessageW(list, LB_GETITEMDATA, sel, 0) : -1;
        }
    }

    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        switch (uMsg)
        {
        case WM_INITDIALOG:
        {
            SalSetDlgItemTextU8(HWindow, IDC_CFGIMP_INTRO, LoadStrU8(IDS_CFGIMP_INTRO));
            HWND list = GetDlgItem(HWindow, IDC_CFGIMP_SOURCES);
            int i;
            int selRow = -1;
            for (i = 0; i < Run->Sources.Count; i++)
            {
                CCfgImpSource* s = &Run->Sources[i];
                char text[500];
                int fmt = s->Support == SALCFGIMP_SUPPORTED ? IDS_CFGIMP_SRC_ITEM : s->Support == SALCFGIMP_TOO_OLD ? IDS_CFGIMP_SRC_TOOOLD
                                                                                                                  : IDS_CFGIMP_SRC_TOONEW;
                if (fmt == IDS_CFGIMP_SRC_ITEM)
                    _snprintf_s(text, _TRUNCATE, LoadStrU8(fmt), s->ProductName, (unsigned)s->ConfigVersion);
                else
                    _snprintf_s(text, _TRUNCATE, LoadStrU8(fmt), s->ProductName);
                int row = (int)SalListBoxAddStringU8(list, text);
                SendMessageW(list, LB_SETITEMDATA, row, i);
                if (s->Support == SALCFGIMP_SUPPORTED && (i == Selected || (selRow < 0 && Selected < 0)))
                    selRow = row;
            }
            if (selRow < 0 && Run->Sources.Count > 0)
            {
                for (i = 0; i < Run->Sources.Count && selRow < 0; i++)
                {
                    if (Run->Sources[(int)SendMessageW(list, LB_GETITEMDATA, i, 0)].Support == SALCFGIMP_SUPPORTED)
                        selRow = i;
                }
            }
            if (selRow >= 0)
                SendMessageW(list, LB_SETCURSEL, selRow, 0);
            UpdateNote();
            break;
        }

        case WM_COMMAND:
        {
            if (LOWORD(wParam) == IDC_CFGIMP_SOURCES && HIWORD(wParam) == LBN_SELCHANGE)
                UpdateNote();
            if (LOWORD(wParam) == IDC_CFGIMP_SOURCES && HIWORD(wParam) == LBN_DBLCLK &&
                IsWindowEnabled(GetDlgItem(HWindow, IDOK)))
                PostMessage(HWindow, WM_COMMAND, IDOK, 0);
            break;
        }
        }
        return CCommonDialog::DialogProc(uMsg, wParam, lParam);
    }
};

//
// ****************************************************************************
// page 2: what to import and how
//

class CCfgImpGroupsPage : public CCommonDialog
{
public:
    CCfgImpRun* Run;
    BOOL Filling;

    CCfgImpGroupsPage(HWND parent, CCfgImpRun* run)
        : CCommonDialog(HLanguage, IDD_CFGIMPORT_GROUPS, CFGIMP_HELPID, parent, ooStandard, NULL, TRUE)
    {
        Run = run;
        Filling = FALSE;
    }

protected:
    HWND List() { return GetDlgItem(HWindow, IDC_CFGIMP_GROUPS); }

    void ModeText(CCfgImpGroup* g, char* buf, int size)
    {
        if (g->Availability != CFGIMP_AVAIL_YES)
            lstrcpyn(buf, g->Reason, size);
        else
            lstrcpyn(buf, LoadStrU8(g->Mode == CFGIMP_MODE_REPLACE ? IDS_CFGIMP_MODE_REPLACE : g->Mode == CFGIMP_MODE_TAKEOVER ? IDS_CFGIMP_MODE_TAKEOVER
                                                                                                                              : IDS_CFGIMP_MODE_ADD),
                     size);
    }

    void UpdateRow(int i)
    {
        CCfgImpGroup* g = Run->Groups[i];
        char text[400];
        ModeText(g, text, (int)sizeof(text));
        SalListViewSetItemTextU8(List(), i, 2, text);
    }

    int CurRow() { return ListView_GetNextItem(List(), -1, LVNI_SELECTED); }

    void UpdateControls()
    {
        int i = CurRow();
        CCfgImpGroup* g = (i >= 0 && i < Run->Groups.Count) ? Run->Groups[i] : NULL;
        BOOL list = g != NULL && g->Availability == CFGIMP_AVAIL_YES && g->ListKind;
        EnableWindow(GetDlgItem(HWindow, IDC_CFGIMP_MODE_ADD), list);
        EnableWindow(GetDlgItem(HWindow, IDC_CFGIMP_MODE_REPLACE), list && g->CanReplace);
        CheckDlgButton(HWindow, IDC_CFGIMP_MODE_ADD, list && g->Mode == CFGIMP_MODE_ADD ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(HWindow, IDC_CFGIMP_MODE_REPLACE, list && g->Mode == CFGIMP_MODE_REPLACE ? BST_CHECKED : BST_UNCHECKED);
        char desc[600];
        desc[0] = 0;
        if (g != NULL)
        {
            if (g->Availability != CFGIMP_AVAIL_YES)
                _snprintf_s(desc, _TRUNCATE, LoadStrU8(IDS_CFGIMP_DESC_UNAVAIL), g->Reason);
            else
                lstrcpyn(desc, LoadStrU8(g->Mode == CFGIMP_MODE_REPLACE ? IDS_CFGIMP_DESC_REPLACE : g->Mode == CFGIMP_MODE_TAKEOVER ? IDS_CFGIMP_DESC_TAKEOVER
                                                                                                                                   : IDS_CFGIMP_DESC_ADD),
                         (int)sizeof(desc));
        }
        SalSetDlgItemTextU8(HWindow, IDC_CFGIMP_ROWDESC, desc);
        BOOL any = FALSE;
        int k;
        for (k = 0; k < Run->Groups.Count; k++)
        {
            if (Run->Groups[k]->Selected && Run->Groups[k]->Availability == CFGIMP_AVAIL_YES)
                any = TRUE;
        }
        EnableWindow(GetDlgItem(HWindow, IDOK), any);
    }

    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        switch (uMsg)
        {
        case WM_INITDIALOG:
        {
            HWND lv = List();
            ListView_SetExtendedListViewStyle(lv, LVS_EX_CHECKBOXES | LVS_EX_FULLROWSELECT);
            RECT r;
            GetClientRect(lv, &r);
            int w = r.right - r.left - GetSystemMetrics(SM_CXVSCROLL);
            LVCOLUMNW col;
            memset(&col, 0, sizeof(col));
            col.mask = LVCF_WIDTH | LVCF_TEXT;
            const WCHAR* empty = L"";
            col.pszText = (LPWSTR)empty;
            col.cx = w * 60 / 100;
            SendMessageW(lv, LVM_INSERTCOLUMNW, 0, (LPARAM)&col);
            col.cx = w * 10 / 100;
            SendMessageW(lv, LVM_INSERTCOLUMNW, 1, (LPARAM)&col);
            col.cx = w - w * 70 / 100;
            SendMessageW(lv, LVM_INSERTCOLUMNW, 2, (LPARAM)&col);
            HWND hdr = ListView_GetHeader(lv);
            if (hdr != NULL)
                ShowWindow(hdr, SW_HIDE); // the label above names the columns
            Filling = TRUE;
            int i;
            for (i = 0; i < Run->Groups.Count; i++)
            {
                CCfgImpGroup* g = Run->Groups[i];
                LVITEMW it;
                memset(&it, 0, sizeof(it));
                it.mask = LVIF_TEXT;
                it.iItem = i;
                it.pszText = (LPWSTR)empty;
                SendMessageW(lv, LVM_INSERTITEMW, 0, (LPARAM)&it);
                SalListViewSetItemTextU8(lv, i, 0, g->Title);
                char num[32];
                _snprintf_s(num, _TRUNCATE, "%d", g->ItemCount);
                SalListViewSetItemTextU8(lv, i, 1, g->Availability == CFGIMP_AVAIL_YES ? num : "");
                UpdateRow(i);
                ListView_SetCheckState(lv, i, g->Selected && g->Availability == CFGIMP_AVAIL_YES);
            }
            Filling = FALSE;
            ListView_SetItemState(lv, 0, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED);
            char notes[1500];
            _snprintf_s(notes, _TRUNCATE, "%s\n%s", LoadStrU8(IDS_CFGIMP_NOTE_FIXEDKEYS), LoadStrU8(IDS_CFGIMP_NOTE_NEVER));
            SalSetDlgItemTextU8(HWindow, IDC_CFGIMP_NOTES, notes);
            UpdateControls();
            break;
        }

        case WM_NOTIFY:
        {
            NMHDR* nm = (NMHDR*)lParam;
            if (nm->idFrom == IDC_CFGIMP_GROUPS && !Filling)
            {
                if (nm->code == LVN_ITEMCHANGING)
                {
                    NMLISTVIEW* lv = (NMLISTVIEW*)lParam;
                    if ((lv->uChanged & LVIF_STATE) && lv->iItem >= 0 && lv->iItem < Run->Groups.Count &&
                        ((lv->uNewState ^ lv->uOldState) & LVIS_STATEIMAGEMASK) != 0 &&
                        Run->Groups[lv->iItem]->Availability != CFGIMP_AVAIL_YES &&
                        (lv->uNewState & LVIS_STATEIMAGEMASK) == INDEXTOSTATEIMAGEMASK(2))
                    {
                        SetWindowLongPtr(HWindow, DWLP_MSGRESULT, TRUE); // an unavailable row cannot be ticked
                        return TRUE;
                    }
                }
                if (nm->code == LVN_ITEMCHANGED)
                {
                    NMLISTVIEW* lv = (NMLISTVIEW*)lParam;
                    if (lv->iItem >= 0 && lv->iItem < Run->Groups.Count && (lv->uChanged & LVIF_STATE))
                    {
                        if (((lv->uNewState ^ lv->uOldState) & LVIS_STATEIMAGEMASK) != 0)
                            Run->Groups[lv->iItem]->Selected = ListView_GetCheckState(List(), lv->iItem) &&
                                                               Run->Groups[lv->iItem]->Availability == CFGIMP_AVAIL_YES;
                        UpdateControls();
                    }
                }
            }
            break;
        }

        case WM_COMMAND:
        {
            int id = LOWORD(wParam);
            if ((id == IDC_CFGIMP_MODE_ADD || id == IDC_CFGIMP_MODE_REPLACE) && HIWORD(wParam) == BN_CLICKED)
            {
                int i = CurRow();
                if (i >= 0 && i < Run->Groups.Count && Run->Groups[i]->ListKind)
                {
                    Run->Groups[i]->Mode = id == IDC_CFGIMP_MODE_REPLACE ? CFGIMP_MODE_REPLACE : CFGIMP_MODE_ADD;
                    UpdateRow(i);
                    UpdateControls();
                }
            }
            if (id == IDC_CFGIMP_BACK)
            {
                EndDialog(HWindow, CFGIMP_RES_BACK);
                return TRUE;
            }
            break;
        }
        }
        return CCommonDialog::DialogProc(uMsg, wParam, lParam);
    }
};

//
// ****************************************************************************
// page 3: saved passwords
//

class CCfgImpPasswordPage : public CCommonDialog
{
public:
    CCfgImpRun* Run;

    CCfgImpPasswordPage(HWND parent, CCfgImpRun* run)
        : CCommonDialog(HLanguage, IDD_CFGIMPORT_PASSWORD, CFGIMP_HELPID, parent, ooStandard, NULL, TRUE)
    {
        Run = run;
    }

protected:
    void EnableControls()
    {
        BOOL import = IsDlgButtonChecked(HWindow, IDC_CFGIMP_PWD_IMPORT) == BST_CHECKED;
        BOOL protectedOnes = Run->Passwords.ProtectedCount > 0;
        EnableWindow(GetDlgItem(HWindow, IDE_CFGIMP_PWD), import && protectedOnes);
        EnableWindow(GetDlgItem(HWindow, IDC_CFGIMP_PWDLABEL), import && protectedOnes);
        EnableWindow(GetDlgItem(HWindow, IDC_CFGIMP_PWD_WEAK), import && protectedOnes);
    }

    // the old program's master password as it used it: code-page bytes of the edit's text
    // (GetDlgItemTextA in both programs; a deliberate exception to the UTF-8 rule, research R10)
    void GetPassword(char* buf, int size)
    {
        WCHAR w[300];
        buf[0] = 0;
        if (GetDlgItemTextW(HWindow, IDE_CFGIMP_PWD, w, 300) > 0)
        {
            if (WideCharToMultiByte(CP_ACP, 0, w, -1, buf, size, NULL, NULL) == 0) // the old program's bytes
                buf[0] = 0;
        }
        SecureZeroMemory(w, sizeof(w));
    }

    virtual void Validate(CTransferInfo& ti)
    {
        if (IsDlgButtonChecked(HWindow, IDC_CFGIMP_PWD_IMPORT) != BST_CHECKED || Run->Passwords.ProtectedCount == 0)
            return;
        char pwd[600];
        GetPassword(pwd, (int)sizeof(pwd));
        if (pwd[0] == 0)
            return; // only the passwords stored without a master password
        const char* product = Run->Sources[Run->Chosen].ProductName;
        char text[600];
        if (!Run->Passwords.SourceVerifierValid)
        {
            _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CFGIMP_PWDNOTVERIFIED), product);
            CfgImpMessage(HWindow, text, MB_OK | MB_ICONEXCLAMATION);
            ti.ErrorOn(IDE_CFGIMP_PWD);
        }
        else if (!Run->CheckSourceMasterPassword(pwd))
        {
            _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CFGIMP_PWDWRONG), product);
            CfgImpMessage(HWindow, text, MB_OK | MB_ICONEXCLAMATION);
            ti.ErrorOn(IDE_CFGIMP_PWD);
        }
        SecureZeroMemory(pwd, sizeof(pwd));
    }

    virtual void Transfer(CTransferInfo& ti)
    {
        if (ti.Type != ttDataFromWindow)
            return;
        BOOL import = IsDlgButtonChecked(HWindow, IDC_CFGIMP_PWD_IMPORT) == BST_CHECKED;
        if (!import)
            Run->Passwords.Policy = SALIMPORT_PWD_NONE;
        else
            Run->Passwords.Policy = Run->Passwords.SourceMasterPassword != NULL ? SALIMPORT_PWD_ALL : SALIMPORT_PWD_SCRAMBLED_ONLY;
        Run->Passwords.AllowWeakerStorage = IsDlgButtonChecked(HWindow, IDC_CFGIMP_PWD_WEAK) == BST_CHECKED;
    }

    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        switch (uMsg)
        {
        case WM_INITDIALOG:
        {
            const char* product = Run->Sources[Run->Chosen].ProductName;
            char text[800];
            _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CFGIMP_PWD_COUNTS), Run->Passwords.ScrambledCount,
                        Run->Passwords.ProtectedCount, product);
            SalSetDlgItemTextU8(HWindow, IDC_CFGIMP_PWDCOUNTS, text);
            BOOL tcUses = PasswordManager.IsUsingMasterPassword();
            SalSetDlgItemTextU8(HWindow, IDC_CFGIMP_PWD_NOTE, LoadStrU8(tcUses ? IDS_CFGIMP_PWD_TCHAS : IDS_CFGIMP_PWD_TCNONE));
            _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CFGIMP_WEAKCONSENT), product);
            SalSetDlgItemTextU8(HWindow, IDC_CFGIMP_PWD_WEAK, text);
            ShowWindow(GetDlgItem(HWindow, IDC_CFGIMP_PWD_WEAK), !tcUses && Run->Passwords.ProtectedCount > 0 ? SW_SHOW : SW_HIDE);
            if (!tcUses && Run->Passwords.AllowWeakerStorage)
                CheckDlgButton(HWindow, IDC_CFGIMP_PWD_WEAK, BST_CHECKED);
            CheckRadioButton(HWindow, IDC_CFGIMP_PWD_IMPORT, IDC_CFGIMP_PWD_SKIP,
                             Run->Passwords.Policy == SALIMPORT_PWD_NONE ? IDC_CFGIMP_PWD_SKIP : IDC_CFGIMP_PWD_IMPORT);
            SendDlgItemMessageW(HWindow, IDE_CFGIMP_PWD, EM_LIMITTEXT, 255, 0);
            EnableControls();
            break;
        }

        case WM_COMMAND:
        {
            int id = LOWORD(wParam);
            if ((id == IDC_CFGIMP_PWD_IMPORT || id == IDC_CFGIMP_PWD_SKIP) && HIWORD(wParam) == BN_CLICKED)
                EnableControls();
            if (id == IDC_CFGIMP_BACK)
            {
                EndDialog(HWindow, CFGIMP_RES_BACK);
                return TRUE;
            }
            break;
        }
        }
        return CCommonDialog::DialogProc(uMsg, wParam, lParam);
    }
};

//
// ****************************************************************************
// pages 4 and 5: the preview and the result
//

class CCfgImpTextPage : public CCommonDialog
{
public:
    CCfgImpRun* Run;
    const char* Text;
    BOOL Result;
    BOOL NeedsConsent;

    CCfgImpTextPage(HWND parent, CCfgImpRun* run, const char* text, BOOL result)
        : CCommonDialog(HLanguage, result ? IDD_CFGIMPORT_RESULT : IDD_CFGIMPORT_PREVIEW, CFGIMP_HELPID, parent,
                        ooStandard, NULL, TRUE)
    {
        Run = run;
        Text = text;
        Result = result;
        NeedsConsent = FALSE;
    }

protected:
    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        switch (uMsg)
        {
        case WM_INITDIALOG:
        {
            HWND edit = GetDlgItem(HWindow, IDE_CFGIMP_TEXT);
            CfgImpSetEditText(edit, Text);
            if (!Result)
            {
                NeedsConsent = Run->NeedsConsent();
                ShowWindow(GetDlgItem(HWindow, IDC_CFGIMP_CONSENT), NeedsConsent ? SW_SHOW : SW_HIDE);
                EnableWindow(GetDlgItem(HWindow, IDOK), !NeedsConsent);
            }
            CCommonDialog::DialogProc(uMsg, wParam, lParam);
            SetFocus(GetDlgItem(HWindow, Result ? IDOK : (NeedsConsent ? IDC_CFGIMP_CONSENT : IDOK)));
            SendMessageW(edit, EM_SETSEL, 0, 0);
            return FALSE; // focus set
        }

        case WM_COMMAND:
        {
            int id = LOWORD(wParam);
            if (id == IDC_CFGIMP_CONSENT && HIWORD(wParam) == BN_CLICKED)
                EnableWindow(GetDlgItem(HWindow, IDOK), IsDlgButtonChecked(HWindow, IDC_CFGIMP_CONSENT) == BST_CHECKED);
            if (id == IDC_CFGIMP_BACK)
            {
                EndDialog(HWindow, CFGIMP_RES_BACK);
                return TRUE;
            }
            if (id == IDC_CFGIMP_COPY)
            {
                CopyTextToClipboardU8Report(HWindow, Text);
                return TRUE;
            }
            if (id == IDC_CFGIMP_SAVE)
            {
                CfgImpSaveReport(HWindow, Text);
                return TRUE;
            }
            if (id == IDOK && !Result && NeedsConsent && IsDlgButtonChecked(HWindow, IDC_CFGIMP_CONSENT) != BST_CHECKED)
                return TRUE; // Import needs the consent
            break;
        }
        }
        return CCommonDialog::DialogProc(uMsg, wParam, lParam);
    }
};

//
// ****************************************************************************
// the wizard
//

static BOOL CfgImpNeedsPasswordPage(CCfgImpRun* run)
{
    return run->IsGroupSelected(cigFTP) && (run->Passwords.ScrambledCount + run->Passwords.ProtectedCount) > 0;
}

void CfgImpRunWizard(HWND parent, BOOL fromOffer)
{
    CALL_STACK_MESSAGE2("CfgImpRunWizard(%d)", fromOffer);
    if (CfgImpOtherInstanceRuns())
    {
        CfgImpMessage(parent, LoadStrU8(IDS_CFGIMP_OTHERINSTANCE), MB_OK | MB_ICONINFORMATION);
        return;
    }
    CCfgImpRun run;
    run.FindSources();
    int selected = -1;
    int page = 0;
    while (TRUE)
    {
        if (page == 0)
        {
            CCfgImpSourcePage dlg(parent, &run, selected);
            INT_PTR res = dlg.Execute();
            if (res != IDOK)
                return;
            selected = dlg.Selected;
            if (selected != run.Chosen || run.Snapshot == NULL)
            {
                char err[500];
                if (!run.OpenSource(selected, err, (int)sizeof(err)))
                {
                    char text[1000];
                    _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CFGIMP_READERR),
                                (selected >= 0 && selected < run.Sources.Count) ? run.Sources[selected].ProductName : "?", err);
                    CfgImpMessage(parent, text, MB_OK | MB_ICONEXCLAMATION);
                    run.FreeSource();
                    run.Chosen = -1;
                    continue;
                }
            }
            page = 1;
        }
        else if (page == 1)
        {
            CCfgImpGroupsPage dlg(parent, &run);
            INT_PTR res = dlg.Execute();
            if (res == CFGIMP_RES_BACK)
            {
                page = 0;
                continue;
            }
            if (res != IDOK)
                return;
            page = CfgImpNeedsPasswordPage(&run) ? 2 : 3;
        }
        else if (page == 2)
        {
            CCfgImpPasswordPage dlg(parent, &run);
            INT_PTR res = dlg.Execute();
            if (res == CFGIMP_RES_BACK)
            {
                page = 1;
                continue;
            }
            if (res != IDOK)
                return;
            page = 3;
        }
        else if (page == 3)
        {
            HCURSOR old = SetCursor(LoadCursor(NULL, IDC_WAIT));
            run.Plan(parent);
            char* text = run.BuildText(FALSE);
            SetCursor(old);
            CCfgImpTextPage dlg(parent, &run, text, FALSE);
            INT_PTR res = dlg.Execute();
            free(text);
            if (res == CFGIMP_RES_BACK)
            {
                page = CfgImpNeedsPasswordPage(&run) ? 2 : 1;
                continue;
            }
            if (res != IDOK)
                return;
            char err[500];
            old = SetCursor(LoadCursor(NULL, IDC_WAIT));
            BOOL applied = run.Apply(parent, err, (int)sizeof(err));
            SetCursor(old);
            if (!applied)
            {
                CfgImpMessage(parent, err, MB_OK | MB_ICONEXCLAMATION);
                continue; // stays on the preview
            }
            page = 4;
        }
        else
        {
            char* text = run.BuildText(TRUE);
            CCfgImpTextPage dlg(parent, &run, text, TRUE);
            dlg.Execute();
            free(text);
            return;
        }
    }
}

//
// ****************************************************************************
// the one-time offer at the first start of a fresh configuration (FR-002)
//

void CfgImpShowFirstStartOffer(HWND parent)
{
    CALL_STACK_MESSAGE1("CfgImpShowFirstStartOffer()");
    if (!CfgImpFreshConfigAtStart)
        return;
    CfgImpFreshConfigAtStart = FALSE;
    if (CfgImpOtherInstanceRuns())
        return;
    CCfgImpRun run;
    run.FindSources(); // existence and version only: no settings are read
    int i;
    const char* product = NULL;
    for (i = 0; i < run.Sources.Count && product == NULL; i++)
    {
        if (run.Sources[i].Support == SALCFGIMP_SUPPORTED)
            product = run.Sources[i].ProductName;
    }
    if (product == NULL)
        return;
    char text[2000];
    _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CFGIMP_OFFER), product);
    char title[200];
    lstrcpyn(title, LoadStrU8(IDS_CFGIMP_TITLE), (int)sizeof(title));
    int res = SalMessageBox(parent, text, title, MB_YESNO | MB_ICONQUESTION);
    // the configuration exists from now on, so the offer never comes back (FR-002)
    MainWindow->SaveConfig(parent);
    if (res == IDYES)
        CfgImpRunWizard(parent, TRUE);
}

//
// ****************************************************************************
// research R18: the Debug-only automation seam
//

#ifdef _DEBUG

BOOL CfgImpAutorunRequested()
{
    WCHAR w[MAX_PATH];
    DWORD l = GetEnvironmentVariableW(L"TC_CFGIMPORT_AUTORUN", w, MAX_PATH);
    return l > 0 && l < MAX_PATH;
}

static void CfgImpWriteFileW(const WCHAR* name, const char* text)
{
    HANDLE h = CreateFileW(name, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE)
        return;
    DWORD written;
    WriteFile(h, "\xEF\xBB\xBF", 3, &written, NULL);
    WriteFile(h, text, (DWORD)strlen(text), &written, NULL);
    CloseHandle(h);
}

static void CfgImpIniString(const WCHAR* file, const WCHAR* key, char* buf, int size)
{
    WCHAR w[2048];
    GetPrivateProfileStringW(L"import", key, L"", w, 2048, file);
    if (SalWToU8(w, -1, buf, size) == 0)
        buf[0] = 0;
}

// script (INI, section [import]):
//   source=<product name or index>   (default: the newest supported)
//   groups=hotpaths:add,usermenu:replace,ftp:add,pluginkeys:add,viewers:add,histories:add,
//          confirmations,panelopts,general,viewer,defaultdirs,plugin:<Configuration Key>, or "defaults"
//   consent=1                        (allow overwrites; without it a plan needing consent is not applied)
//   pwdpolicy=0|1|2                  masterpassword=<text>   weakconsent=0|1
//   close=0|1                        (default 1: close the program afterwards)
// writes <script>.preview.txt and <script>.result.txt (or <script>.error.txt)
void CfgImpRunAutomation(HWND parent)
{
    WCHAR script[MAX_PATH];
    DWORD l = GetEnvironmentVariableW(L"TC_CFGIMPORT_AUTORUN", script, MAX_PATH);
    if (l == 0 || l >= MAX_PATH)
        return;
    SetEnvironmentVariableW(L"TC_CFGIMPORT_AUTORUN", NULL); // once
    WCHAR out[MAX_PATH + 32];
    char buf[4096];
    CCfgImpRun run;
    run.Automation = TRUE;
    run.FindSources();
    CfgImpIniString(script, L"source", buf, sizeof(buf));
    int src = -1;
    int i;
    for (i = 0; i < run.Sources.Count && src < 0; i++)
    {
        if (run.Sources[i].Support != SALCFGIMP_SUPPORTED && buf[0] == 0)
            continue;
        if (buf[0] == 0 || _stricmp(buf, run.Sources[i].ProductName) == 0)
            src = i;
    }
    if (src < 0 && buf[0] >= '0' && buf[0] <= '9')
        src = atoi(buf);
    char err[500] = "";
    BOOL closeAfter = GetPrivateProfileIntW(L"import", L"close", 1, script) != 0;
    if (src < 0 || !run.OpenSource(src, err, (int)sizeof(err)))
    {
        swprintf_s(out, L"%s.error.txt", script);
        char text[1000];
        _snprintf_s(text, _TRUNCATE, "source not opened (%d sources): %s\r\n", run.Sources.Count, err);
        for (i = 0; i < run.Sources.Count; i++)
        {
            char line[500];
            _snprintf_s(line, _TRUNCATE, "%s|%u|%d\r\n", run.Sources[i].ProductName, (unsigned)run.Sources[i].ConfigVersion,
                        run.Sources[i].Support);
            strncat_s(text, line, _TRUNCATE);
        }
        CfgImpWriteFileW(out, text);
        if (closeAfter)
            PostMessage(parent, WM_CLOSE, 0, 0);
        return;
    }
    CfgImpIniString(script, L"groups", buf, sizeof(buf));
    if (_stricmp(buf, "defaults") != 0)
    {
        static const struct
        {
            const char* Name;
            CCfgImpGroupId Id;
        } names[] = {{"hotpaths", cigHotPaths}, {"usermenu", cigUserMenu}, {"ftp", cigFTP}, {"pluginkeys", cigPluginKeys}, {"viewers", cigViewers}, {"histories", cigHistories}, {"confirmations", cigConfirmations}, {"panelopts", cigPanelOpts}, {"general", cigGeneral}, {"viewer", cigViewerOpts}, {"defaultdirs", cigDefaultDirs}};
        for (i = 0; i < run.Groups.Count; i++)
            run.Groups[i]->Selected = FALSE;
        char* ctx = NULL;
        char* tok = strtok_s(buf, ",", &ctx);
        while (tok != NULL)
        {
            while (*tok == ' ')
                tok++;
            char* mode = strchr(tok, ':');
            int m = 0;
            if (mode != NULL && _strnicmp(tok, "plugin:", 7) != 0)
            {
                *mode++ = 0;
                m = _stricmp(mode, "replace") == 0 ? CFGIMP_MODE_REPLACE : CFGIMP_MODE_ADD;
            }
            for (i = 0; i < run.Groups.Count; i++)
            {
                CCfgImpGroup* g = run.Groups[i];
                BOOL match = FALSE;
                if (_strnicmp(tok, "plugin:", 7) == 0)
                    match = g->Id == cigPluginSettings && _stricmp(tok + 7, g->PluginKey) == 0;
                else
                {
                    int n;
                    for (n = 0; n < (int)(sizeof(names) / sizeof(names[0])); n++)
                    {
                        if (_stricmp(tok, names[n].Name) == 0 && g->Id == names[n].Id)
                            match = TRUE;
                    }
                }
                if (match && g->Availability == CFGIMP_AVAIL_YES)
                {
                    g->Selected = TRUE;
                    if (m != 0 && g->ListKind && (m == CFGIMP_MODE_ADD || g->CanReplace))
                        g->Mode = m;
                }
            }
            tok = strtok_s(NULL, ",", &ctx);
        }
    }
    run.Passwords.Policy = GetPrivateProfileIntW(L"import", L"pwdpolicy", SALIMPORT_PWD_SCRAMBLED_ONLY, script);
    run.Passwords.AllowWeakerStorage = GetPrivateProfileIntW(L"import", L"weakconsent", 0, script) != 0;
    CfgImpIniString(script, L"masterpassword", buf, sizeof(buf));
    if (buf[0] != 0 && !run.CheckSourceMasterPassword(buf))
        run.Passwords.Policy = min(run.Passwords.Policy, SALIMPORT_PWD_SCRAMBLED_ONLY);
    if (run.Passwords.Policy == SALIMPORT_PWD_ALL && run.Passwords.SourceMasterPassword == NULL)
        run.Passwords.Policy = SALIMPORT_PWD_SCRAMBLED_ONLY;

    run.Plan(parent);
    char* text = run.BuildText(FALSE);
    swprintf_s(out, L"%s.preview.txt", script);
    CfgImpWriteFileW(out, text);
    free(text);
    BOOL consent = GetPrivateProfileIntW(L"import", L"consent", 0, script) != 0;
    if (run.NeedsConsent() && !consent)
    {
        swprintf_s(out, L"%s.result.txt", script);
        CfgImpWriteFileW(out, "NOT APPLIED: consent needed\r\n");
    }
    else if (!run.Apply(parent, err, (int)sizeof(err)))
    {
        swprintf_s(out, L"%s.result.txt", script);
        char t2[600];
        _snprintf_s(t2, _TRUNCATE, "NOT APPLIED: %s\r\n", err);
        CfgImpWriteFileW(out, t2);
    }
    else
    {
        text = run.BuildText(TRUE);
        swprintf_s(out, L"%s.result.txt", script);
        CfgImpWriteFileW(out, text);
        free(text);
    }
    if (closeAfter)
        PostMessage(parent, WM_CLOSE, 0, 0);
}

#endif // _DEBUG
