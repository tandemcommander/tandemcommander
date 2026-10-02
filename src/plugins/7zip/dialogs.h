// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//****************************************************************************
//
// CCommonDialog
//
// Dialog centered to the parent
//

class CCommonDialog : public CDialog
{
public:
    CCommonDialog(HINSTANCE hInstance, int resID, HWND hParent, CObjectOrigin origin = ooStandard);
    CCommonDialog(HINSTANCE hInstance, int resID, int helpID, HWND hParent, CObjectOrigin origin = ooStandard);

protected:
    INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);

    virtual void NotifDlgJustCreated();
};

//****************************************************************************
//
// CCompressParamsDlg
//

class CCompressParamsDlg
{
private:
    int IDCfgCompressLevel;
    int IDCfgCompressMethod;
    int IDCfgDictSize;
    int IDCfgWordSize;
    int IDCfgSolidArchive;

public:
    CCompressParams* CompressParams;
    HWND HWindow;

    CCompressParamsDlg(CCompressParams* compressParams, int IDCfgCompressLevel, int IDCfgCompressMethod, int IDCfgDictSize,
                       int IDCfgWordSize, int IDCfgSolidArchive);
    virtual void Transfer(CTransferInfo& ti);

    INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);

protected:
    void FillCompressLevelCombo();
    void FillCompressMethodCombo();
    void FillDictSizeCombo(int values[], int size);
    void FillWordSizeCombo(int values[], int size);

    void OnChangeMethod();
    void OnChangeLevel();
};

//****************************************************************************
//
// CConfigurationDialog
//

class CConfigurationDialog : public CCommonDialog
{
public:
    CCompressParamsDlg CompressParamsDlg;
    CConfig Cfg;

    CConfigurationDialog(HWND hParent);

    virtual void Transfer(CTransferInfo& ti);

protected:
    INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
};

//****************************************************************************
//
// CNewArchiveDialog
//

// feature 093: a password is UTF-16 from the field to the engine; the limit is
// in characters (units), terminator included
#define PASSWORD_LEN 128

// feature 093: reads a password field wide / writes it back, wipes a buffer
void TransferPasswordField(HWND dialog, int ctrlID, CTransferInfo& ti, WCHAR* password);
inline void WipePassword(WCHAR* password) { SecureZeroMemory(password, PASSWORD_LEN * sizeof(WCHAR)); }

class CExtOptionsDialog : public CCommonDialog
{
private:
    char Archive[MAX_PATH];

    WCHAR Password[PASSWORD_LEN];
    WCHAR ConfirmedPassword[PASSWORD_LEN];
    BOOL NotAgain;
    BOOL Encrypt;

    const char* Title;

    CCompressParamsDlg CompressParamsDlg;

public:
    CCompressParams CompressParams;

    CExtOptionsDialog(HWND hParent);
    ~CExtOptionsDialog();
    virtual void Transfer(CTransferInfo& ti);
    BOOL CreateChilds();

    BOOL IsPasswordDefined() { return Encrypt; }
    const WCHAR* GetPassword() { return Password; } // the typed text, UTF-16
    BOOL GetNotAgain() { return NotAgain; }
    // display only: this is an ANSI dialog, so a long or non-ASCII UTF-8 archive
    // name is truncated/garbled here; a bounded copy at least keeps it safe
    void SetArchiveName(const char* archiveName) { lstrcpyn(Archive, archiveName, MAX_PATH); }
    void SetTitle(const char* title) { Title = title; }

protected:
    INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
};

//****************************************************************************
//
// CEnterPasswordDialog
//

class CEnterPasswordDialog : public CCommonDialog
{
private:
    //    char FileName[MAX_PATH];
    WCHAR Password[PASSWORD_LEN];

public:
    CEnterPasswordDialog(HWND hParent);
    ~CEnterPasswordDialog();
    virtual void Transfer(CTransferInfo& ti);

    const WCHAR* GetPassword() { return Password; } // the typed text, UTF-16
    //    void SetFileName(const char *fileName) { lstrcpy(FileName, fileName); }

protected:
    INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
};
