using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public static class B1Probe
{
    public delegate IntPtr DlgProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public int ptx; public int pty; }

    [DllImport("user32.dll")] static extern IntPtr CreateDialogIndirectParamA(IntPtr hInst, IntPtr tmpl, IntPtr parent, DlgProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr CreateDialogIndirectParamW(IntPtr hInst, IntPtr tmpl, IntPtr parent, DlgProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr DialogBoxIndirectParamA(IntPtr hInst, IntPtr tmpl, IntPtr parent, DlgProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr DialogBoxIndirectParamW(IntPtr hInst, IntPtr tmpl, IntPtr parent, DlgProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EndDialog(IntPtr hwnd, IntPtr res);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr hwnd, int id);
    [DllImport("user32.dll")] static extern bool IsWindowUnicode(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hwnd, uint cmd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool SetWindowTextW(IntPtr hwnd, string s);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextW(IntPtr hwnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] static extern int GetWindowTextA(IntPtr hwnd, byte[] buf, int max);
    [DllImport("user32.dll")] static extern IntPtr SendMessageA(IntPtr hwnd, uint msg, IntPtr wParam, byte[] lParam);
    [DllImport("user32.dll", EntryPoint = "SendMessageA")] static extern IntPtr SendMessageA_p(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessageW(IntPtr hwnd, uint msg, IntPtr wParam, string lParam);
    [DllImport("user32.dll", EntryPoint = "SendMessageW")] static extern IntPtr SendMessageW_p(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", EntryPoint = "SendMessageW", CharSet = CharSet.Unicode)] static extern IntPtr SendMessageW_sb(IntPtr hwnd, uint msg, IntPtr wParam, StringBuilder lParam);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool PostMessageA(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool PeekMessageA(out MSG msg, IntPtr hwnd, uint min, uint max, uint remove);
    [DllImport("user32.dll")] static extern bool PeekMessageW(out MSG msg, IntPtr hwnd, uint min, uint max, uint remove);
    [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG msg);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessageA(ref MSG msg);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessageW(ref MSG msg);
    [DllImport("user32.dll")] static extern bool IsDialogMessageA(IntPtr hDlg, ref MSG msg);
    [DllImport("user32.dll")] static extern bool IsDialogMessageW(IntPtr hDlg, ref MSG msg);
    [DllImport("user32.dll")] static extern IntPtr SetWindowLongPtrA(IntPtr hwnd, int idx, IntPtr val);
    [DllImport("user32.dll")] static extern IntPtr SetWindowLongPtrW(IntPtr hwnd, int idx, IntPtr val);
    [DllImport("user32.dll")] static extern IntPtr GetWindowLongPtrA(IntPtr hwnd, int idx);
    [DllImport("user32.dll")] static extern IntPtr GetWindowLongPtrW(IntPtr hwnd, int idx);
    [DllImport("user32.dll")] static extern IntPtr CallWindowProcA(IntPtr prev, IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr CallWindowProcW(IntPtr prev, IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateWindowExW(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr param);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] static extern IntPtr CreateWindowExA(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr param);
    [DllImport("kernel32.dll")] static extern uint GetACP();
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandleW(IntPtr p);

    const uint WM_SETTEXT = 0x000C, WM_GETTEXT = 0x000D, WM_CHAR = 0x0102, WM_INITDIALOG = 0x0110, WM_APP = 0x8000, WM_COMMAND = 0x0111;
    const uint CB_ADDSTRING = 0x0143, CB_GETLBTEXT = 0x0148, CB_SETCURSEL = 0x014E, EM_REPLACESEL = 0x00C2;
    const uint WS_CHILD = 0x40000000, WS_BORDER = 0x00800000, WS_POPUP = 0x80000000, WS_CAPTION = 0x00C00000, WS_TABSTOP = 0x00010000, WS_VISIBLE = 0x10000000;
    const uint ES_AUTOHSCROLL = 0x0080, CBS_DROPDOWN = 0x0002, CBS_AUTOHSCROLL = 0x0040, CBS_HASSTRINGS = 0x0200;
    const int GWLP_WNDPROC = -4;
    const int ID_EDIT = 100, ID_COMBO = 101, ID_EDITW = 200;

    static List<Delegate> keep = new List<Delegate>();
    static StringBuilder log = new StringBuilder();
    static void L(string s) { log.AppendLine(s); }

    static string Hex(string s) { var sb = new StringBuilder(); foreach (char c in s) sb.AppendFormat("{0:X4} ", (int)c); return sb.ToString().Trim(); }
    static string GetW(IntPtr h) { var sb = new StringBuilder(256); GetWindowTextW(h, sb, 256); return sb.ToString(); }

    // DLGTEMPLATE with one EDIT (id 100) and one COMBOBOX (id 101); never visible
    static IntPtr BuildTemplate()
    {
        var b = new List<byte>();
        Action<uint> dw = v => b.AddRange(BitConverter.GetBytes(v));
        Action<ushort> w = v => b.AddRange(BitConverter.GetBytes(v));
        Action align = () => { while (b.Count % 4 != 0) b.Add(0); };
        dw(WS_POPUP | WS_CAPTION); dw(0); w(2); w(0); w(0); w(200); w(80);
        w(0); w(0); w(0); // menu, class, title
        align();
        dw(WS_CHILD | WS_BORDER | WS_TABSTOP | ES_AUTOHSCROLL | WS_VISIBLE); dw(0); w(5); w(5); w(150); w(14); w(ID_EDIT);
        w(0xFFFF); w(0x0081); w(0); w(0);
        align();
        dw(WS_CHILD | WS_TABSTOP | CBS_DROPDOWN | CBS_AUTOHSCROLL | CBS_HASSTRINGS | WS_VISIBLE); dw(0); w(5); w(25); w(150); w(60); w(ID_COMBO);
        w(0xFFFF); w(0x0085); w(0); w(0);
        align();
        IntPtr p = Marshal.AllocHGlobal(b.Count);
        Marshal.Copy(b.ToArray(), 0, p, b.Count);
        return p;
    }

    static IntPtr NullDlgProc(IntPtr h, uint m, IntPtr w, IntPtr l) { return (m == WM_INITDIALOG) ? (IntPtr)1 : IntPtr.Zero; }

    // pump modes: 0 = PeekW+DispatchW, 1 = PeekA+DispatchA, 2 = PeekW+IsDialogMessageA(+DispatchW),
    // 3 = PeekW+IsDialogMessageW, 4 = PeekA+IsDialogMessageA(+DispatchA), 5 = PeekA + IsDialogMessageW
    static string[] modeNames = { "PeekW + DispatchW", "PeekA + DispatchA", "PeekW + IsDialogMessageA (main loop of salamdr1.cpp)", "PeekW + IsDialogMessageW", "PeekA + IsDialogMessageA (find.cpp / sheets.cpp loop)", "PeekA + IsDialogMessageW" };
    static void Pump(IntPtr dlg, int mode)
    {
        MSG m;
        for (int guard = 0; guard < 1000; guard++)
        {
            bool got = (mode == 1 || mode == 4 || mode == 5) ? PeekMessageA(out m, IntPtr.Zero, 0, 0, 1) : PeekMessageW(out m, IntPtr.Zero, 0, 0, 1);
            if (!got) break;
            switch (mode)
            {
                case 0: DispatchMessageW(ref m); break;
                case 1: DispatchMessageA(ref m); break;
                case 2: if (!IsDialogMessageA(dlg, ref m)) DispatchMessageW(ref m); break;
                case 3: if (!IsDialogMessageW(dlg, ref m)) DispatchMessageW(ref m); break;
                case 4: if (!IsDialogMessageA(dlg, ref m)) DispatchMessageA(ref m); break;
                case 5: if (!IsDialogMessageW(dlg, ref m)) DispatchMessageA(ref m); break;
            }
        }
    }

    static string TypeChars(IntPtr dlg, IntPtr edit, string chars, int mode)
    {
        SetWindowTextW(edit, "");
        foreach (char c in chars) PostMessageW(edit, WM_CHAR, (IntPtr)c, (IntPtr)1);
        Pump(dlg, mode);
        return GetW(edit);
    }

    static IntPtr oldProc; static bool subUnicodeCall;
    static IntPtr SubProc(IntPtr h, uint m, IntPtr w, IntPtr l)
    {
        return subUnicodeCall ? CallWindowProcW(oldProc, h, m, w, l) : CallWindowProcA(oldProc, h, m, w, l);
    }

    static string modalResult; static bool modalMakeWChild; static string modalChars;
    static IntPtr ModalProc(IntPtr h, uint m, IntPtr w, IntPtr l)
    {
        if (m == WM_INITDIALOG)
        {
            IntPtr target = GetDlgItem(h, ID_EDIT);
            if (modalMakeWChild)
                target = CreateWindowExW(0, "EDIT", "", WS_CHILD | WS_BORDER | ES_AUTOHSCROLL, 5, 60, 150, 20, h, (IntPtr)ID_EDITW, GetModuleHandleW(IntPtr.Zero), IntPtr.Zero);
            foreach (char c in modalChars) PostMessageW(target, WM_CHAR, (IntPtr)c, (IntPtr)1);
            PostMessageW(h, WM_APP, IntPtr.Zero, IntPtr.Zero);
            return (IntPtr)1;
        }
        if (m == WM_APP)
        {
            IntPtr target = GetDlgItem(h, modalMakeWChild ? ID_EDITW : ID_EDIT);
            modalResult = "IsWindowUnicode(dlg)=" + IsWindowUnicode(h) + " IsWindowUnicode(edit)=" + IsWindowUnicode(target) + " text=" + Hex(GetW(target));
            EndDialog(h, (IntPtr)1);
            return (IntPtr)1;
        }
        return IntPtr.Zero;
    }

    public static string Run()
    {
        string sample = "ařЖ日"; // a, r-caron (in CP1250), Cyrillic ZHE, CJK
        string sampleSurr = "📁";     // U+1F4C1 as a surrogate pair
        L("ACP = " + GetACP() + "   sample = " + Hex(sample));
        IntPtr tmpl = BuildTemplate();
        DlgProc proc = NullDlgProc; keep.Add(proc);
        IntPtr hInst = GetModuleHandleW(IntPtr.Zero);

        for (int pass = 0; pass < 2; pass++)
        {
            bool wide = pass == 1;
            L("");
            L("=== Dialog created with CreateDialogIndirectParam" + (wide ? "W" : "A") + " (same DLGPROC) ===");
            IntPtr dlg = wide ? CreateDialogIndirectParamW(hInst, tmpl, IntPtr.Zero, proc, IntPtr.Zero) : CreateDialogIndirectParamA(hInst, tmpl, IntPtr.Zero, proc, IntPtr.Zero);
            IntPtr edit = GetDlgItem(dlg, ID_EDIT), combo = GetDlgItem(dlg, ID_COMBO), comboEdit = GetWindow(combo, 5 /*GW_CHILD*/);
            L("IsWindowUnicode: dialog=" + IsWindowUnicode(dlg) + " edit=" + IsWindowUnicode(edit) + " combo=" + IsWindowUnicode(combo) + " comboEdit=" + IsWindowUnicode(comboEdit));

            SetWindowTextW(edit, sample);
            L("T1 SetWindowTextW(edit) -> GetWindowTextW: " + Hex(GetW(edit)));
            SetWindowTextW(combo, sample);
            L("T1 SetWindowTextW(combo) -> GetWindowTextW: " + Hex(GetW(combo)));

            // ANSI text sent with SendMessageA into the control
            byte[] ansi = Encoding.GetEncoding((int)GetACP()).GetBytes("ařz\0");
            SendMessageA(edit, WM_SETTEXT, IntPtr.Zero, ansi);
            L("T2 SendMessageA(WM_SETTEXT, ACP bytes of 'a r-caron z') -> GetWindowTextW: " + Hex(GetW(edit)));
            byte[] back = new byte[64]; SetWindowTextW(edit, sample); int n = GetWindowTextA(edit, back, 64);
            L("T2 SetWindowTextW(sample) -> GetWindowTextA bytes: " + BitConverter.ToString(back, 0, n));

            // combo list strings
            SendMessageW(combo, CB_ADDSTRING, IntPtr.Zero, sample);
            var sb = new StringBuilder(256); SendMessageW_sb(combo, CB_GETLBTEXT, IntPtr.Zero, sb);
            L("T3 CB_ADDSTRING (W) -> CB_GETLBTEXT (W): " + Hex(sb.ToString()));
            SendMessageW_p(combo, CB_SETCURSEL, IntPtr.Zero, IntPtr.Zero);
            L("T3 CB_SETCURSEL -> GetWindowTextW(combo): " + Hex(GetW(combo)));

            // EM_REPLACESEL wide
            SetWindowTextW(edit, ""); SendMessageW(edit, EM_REPLACESEL, (IntPtr)1, sample);
            L("T4 SendMessageW(EM_REPLACESEL) -> GetWindowTextW: " + Hex(GetW(edit)));

            // typing through each pump
            for (int mode = 0; mode < 6; mode++)
                L("T5 typed WM_CHAR, pump [" + modeNames[mode] + "] -> edit: " + Hex(TypeChars(dlg, edit, sample, mode)));
            L("T5 surrogate pair, pump [PeekW + IsDialogMessageW] -> edit: " + Hex(TypeChars(dlg, edit, sampleSurr, 3)));
            L("T5 surrogate pair, pump [PeekA + IsDialogMessageA] -> edit: " + Hex(TypeChars(dlg, edit, sampleSurr, 4)));
            for (int mode = 2; mode < 5; mode++)
                L("T5 typed into COMBO EDIT, pump [" + modeNames[mode] + "] -> " + Hex(TypeChars(dlg, comboEdit, sample, mode)));

            // approach (ii): a CreateWindowExW EDIT child inside this dialog
            IntPtr editW = CreateWindowExW(0, "EDIT", "", WS_CHILD | WS_BORDER | ES_AUTOHSCROLL, 5, 60, 150, 20, dlg, (IntPtr)ID_EDITW, hInst, IntPtr.Zero);
            L("T6 CreateWindowExW EDIT child: IsWindowUnicode=" + IsWindowUnicode(editW));
            SetWindowTextW(editW, sample);
            L("T6 SetWindowTextW -> GetWindowTextW: " + Hex(GetW(editW)));
            for (int mode = 0; mode < 6; mode++)
                L("T6 typed WM_CHAR, pump [" + modeNames[mode] + "] -> W child: " + Hex(TypeChars(dlg, editW, sample, mode)));
            IntPtr editA = CreateWindowExA(0, "EDIT", "", WS_CHILD | WS_BORDER | ES_AUTOHSCROLL, 5, 80, 150, 20, dlg, (IntPtr)201, hInst, IntPtr.Zero);
            L("T6b CreateWindowExA EDIT child: IsWindowUnicode=" + IsWindowUnicode(editA));

            // subclassing: SetWindowLongPtrA vs W on the template edit
            DlgProc sub = SubProc; keep.Add(sub);
            IntPtr fp = Marshal.GetFunctionPointerForDelegate(sub);
            SetWindowTextW(edit, sample);
            subUnicodeCall = false;
            oldProc = GetWindowLongPtrA(edit, GWLP_WNDPROC);
            SetWindowLongPtrA(edit, GWLP_WNDPROC, fp);
            L("T7 after SetWindowLongPtrA(GWLP_WNDPROC) subclass: IsWindowUnicode(edit)=" + IsWindowUnicode(edit) + "  existing text read W: " + Hex(GetW(edit)));
            SetWindowTextW(edit, sample);
            L("T7 SetWindowTextW after A-subclass -> GetWindowTextW: " + Hex(GetW(edit)));
            L("T7 typed after A-subclass, pump [PeekW + IsDialogMessageW] -> " + Hex(TypeChars(dlg, edit, sample, 3)));
            SetWindowLongPtrA(edit, GWLP_WNDPROC, oldProc);
            L("T7 after restoring with SetWindowLongPtrA: IsWindowUnicode(edit)=" + IsWindowUnicode(edit));
            subUnicodeCall = true;
            oldProc = GetWindowLongPtrW(edit, GWLP_WNDPROC);
            SetWindowLongPtrW(edit, GWLP_WNDPROC, fp);
            L("T8 after SetWindowLongPtrW(GWLP_WNDPROC) subclass: IsWindowUnicode(edit)=" + IsWindowUnicode(edit));
            SetWindowTextW(edit, sample);
            L("T8 SetWindowTextW after W-subclass -> GetWindowTextW: " + Hex(GetW(edit)));
            L("T8 typed after W-subclass, pump [PeekW + IsDialogMessageW] -> " + Hex(TypeChars(dlg, edit, sample, 3)));
            L("T8 typed after W-subclass, pump [PeekW + IsDialogMessageA] -> " + Hex(TypeChars(dlg, edit, sample, 2)));
            SetWindowLongPtrW(edit, GWLP_WNDPROC, oldProc);
            DestroyWindow(dlg);
        }

        // modal loops
        DlgProc mp = ModalProc; keep.Add(mp);
        modalChars = sample;
        L("");
        L("=== Modal dialogs (the dialog manager's own message loop) ===");
        modalMakeWChild = false; DialogBoxIndirectParamA(hInst, tmpl, IntPtr.Zero, mp, IntPtr.Zero);
        L("T9 DialogBoxIndirectParamA, typed into template edit: " + modalResult);
        modalMakeWChild = false; DialogBoxIndirectParamW(hInst, tmpl, IntPtr.Zero, mp, IntPtr.Zero);
        L("T9 DialogBoxIndirectParamW, typed into template edit: " + modalResult);
        modalMakeWChild = true; DialogBoxIndirectParamA(hInst, tmpl, IntPtr.Zero, mp, IntPtr.Zero);
        L("T9 DialogBoxIndirectParamA, typed into a CreateWindowExW edit child: " + modalResult);
        modalChars = sampleSurr; modalMakeWChild = false; DialogBoxIndirectParamW(hInst, tmpl, IntPtr.Zero, mp, IntPtr.Zero);
        L("T9 DialogBoxIndirectParamW, surrogate pair typed: " + modalResult);
        return log.ToString();
    }
}
