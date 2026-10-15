# Feature 193 probe library: collects OutputDebugString text of the processes of this session
# (the DBWIN_BUFFER protocol a debug-output viewer uses), so that the Debug heap's leak dump at
# exit can be read without a debugger. Dot-sourced. Pure ASCII, PowerShell 5.1.
if (-not ('DbWin193' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class DbWin193
{
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr CreateEventW(IntPtr a, bool manual, bool initial, string name);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr CreateFileMappingW(IntPtr h, IntPtr a, uint protect, uint hi, uint lo, string name);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr MapViewOfFile(IntPtr h, uint access, uint hi, uint lo, UIntPtr n);
    [DllImport("kernel32.dll")] static extern bool SetEvent(IntPtr h);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    static IntPtr bufReady, dataReady, view;
    static volatile bool stop;
    static Thread thread;
    public static List<string> Lines = new List<string>();
    public static string Start()
    {
        bufReady = CreateEventW(IntPtr.Zero, false, false, "DBWIN_BUFFER_READY");
        dataReady = CreateEventW(IntPtr.Zero, false, false, "DBWIN_DATA_READY");
        IntPtr map = CreateFileMappingW(new IntPtr(-1), IntPtr.Zero, 4, 0, 4096, "DBWIN_BUFFER");
        if (bufReady == IntPtr.Zero || dataReady == IntPtr.Zero || map == IntPtr.Zero) return "not available: " + Marshal.GetLastWin32Error();
        view = MapViewOfFile(map, 4, 0, 0, (UIntPtr)4096);
        if (view == IntPtr.Zero) return "no view: " + Marshal.GetLastWin32Error();
        stop = false;
        thread = new Thread(Loop); thread.IsBackground = true; thread.Start();
        return "listening";
    }
    static void Loop()
    {
        SetEvent(bufReady);
        while (!stop)
        {
            if (WaitForSingleObject(dataReady, 200) != 0) continue;
            int pid = Marshal.ReadInt32(view);
            byte[] b = new byte[4092];
            Marshal.Copy(view + 4, b, 0, b.Length);
            int z = Array.IndexOf(b, (byte)0); if (z < 0) z = b.Length;
            string s = Encoding.Default.GetString(b, 0, z);
            lock (Lines) Lines.Add(pid + ": " + s.TrimEnd('\r', '\n'));
            SetEvent(bufReady);
        }
    }
    public static string[] Take() { lock (Lines) { var a = Lines.ToArray(); Lines.Clear(); return a; } }
    public static void Stop() { stop = true; if (thread != null) thread.Join(1000); }
}
'@
}
