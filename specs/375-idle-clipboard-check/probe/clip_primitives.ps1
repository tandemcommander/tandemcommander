<#
  Times the clipboard queries of the idle clipboard check (CMainWindow::RefreshCommandStates):
  OpenClipboard / GetClipboardData(CF_TEXT) / CloseClipboard (IsTextOnClipboard, with its retry loop),
  OleGetClipboard + EnumFormatEtc (ClipboardPaste, ClipboardPasteToArcOrFS). Read-only: nothing is
  written to the clipboard.
#>
param([int]$Rounds = 5)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class Clip375
{
    [DllImport("user32.dll", SetLastError = true)] public static extern bool OpenClipboard(IntPtr h);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool CloseClipboard();
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr GetClipboardData(uint f);
    [DllImport("user32.dll")] public static extern IntPtr GetOpenClipboardWindow();
    [DllImport("user32.dll")] public static extern IntPtr GetClipboardOwner();
    [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
    [DllImport("user32.dll")] public static extern bool IsClipboardFormatAvailable(uint f);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("ole32.dll")] public static extern int OleInitialize(IntPtr p);
    [DllImport("ole32.dll")] public static extern int OleGetClipboard(out IntPtr obj);
    [DllImport("kernel32.dll")] public static extern void Sleep(uint ms);

    [ComImport, Guid("00000103-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IEnumFORMATETCRaw { [PreserveSig] int Next(int celt, IntPtr rgelt, IntPtr fetched); [PreserveSig] int Skip(int c); [PreserveSig] int Reset(); [PreserveSig] int Clone(out IntPtr e); }

    static double Ms(Stopwatch s) { return s.Elapsed.TotalMilliseconds; }

    public static string OneRound()
    {
        StringBuilder sb = new StringBuilder();
        uint pid;
        IntPtr ow = GetOpenClipboardWindow(); GetWindowThreadProcessId(ow, out pid);
        sb.AppendFormat("seq {0}; open-window {1} (pid {2}); owner {3}; ", GetClipboardSequenceNumber(), ow, pid, GetClipboardOwner());
        var s = Stopwatch.StartNew();
        bool ok = OpenClipboard(IntPtr.Zero); int err = Marshal.GetLastWin32Error();
        double t1 = Ms(s);
        bool text = false;
        if (ok) { text = GetClipboardData(1) != IntPtr.Zero; CloseClipboard(); }
        sb.AppendFormat("OpenClipboard {0} err {1} {2:N2} ms, text {3}, with Get+Close {4:N2} ms; ", ok, err, t1, text, Ms(s));
        // IsTextOnClipboard as written: up to 10 x Sleep(10) while OpenClipboard fails
        s.Restart(); int attempt = 1; int fails = 0;
        while (true) { if (OpenClipboard(IntPtr.Zero)) { GetClipboardData(1); CloseClipboard(); break; } fails++; if (attempt++ <= 10) Sleep(10); else break; }
        sb.AppendFormat("IsTextOnClipboard loop {0:N2} ms ({1} failed opens); ", Ms(s), fails);
        s.Restart(); bool avail = IsClipboardFormatAvailable(15); sb.AppendFormat("IsClipboardFormatAvailable(CF_HDROP) {0} {1:N2} ms; ", avail, Ms(s));
        // OleGetClipboard + EnumFormatEtc
        s.Restart(); IntPtr p; int hr = OleGetClipboard(out p); double tg = Ms(s);
        int nfmt = -1; double te = 0;
        if (hr == 0 && p != IntPtr.Zero)
        {
            var o = (System.Runtime.InteropServices.ComTypes.IDataObject)Marshal.GetObjectForIUnknown(p);
            var s2 = Stopwatch.StartNew();
            try
            {
                var en = o.EnumFormatEtc(System.Runtime.InteropServices.ComTypes.DATADIR.DATADIR_GET);
                nfmt = 0; var f = new System.Runtime.InteropServices.ComTypes.FORMATETC[1]; var got = new int[1];
                en.Reset(); while (en.Next(1, f, got) == 0) nfmt++;
                Marshal.ReleaseComObject(en);
            }
            catch (Exception e) { sb.Append("enum: " + e.GetType().Name + " " + e.Message + "; "); }
            te = Ms(s2);
            Marshal.ReleaseComObject(o); Marshal.Release(p);
        }
        sb.AppendFormat("OleGetClipboard hr 0x{0:X8} {1:N2} ms, EnumFormatEtc {2} formats {3:N2} ms", hr, tg, nfmt, te);
        return sb.ToString();
    }
}
'@
[void][Clip375]::OleInitialize([IntPtr]::Zero)
"clip_primitives: apartment {0}; session {1}" -f [Threading.Thread]::CurrentThread.GetApartmentState(), [Diagnostics.Process]::GetCurrentProcess().SessionId
for ($i = 0; $i -lt $Rounds; $i++) { "#{0}: {1}" -f $i, [Clip375]::OneRound(); Start-Sleep -Milliseconds 200 }
