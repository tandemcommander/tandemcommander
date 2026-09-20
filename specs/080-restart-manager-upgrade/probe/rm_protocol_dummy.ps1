<#
.SYNOPSIS
    Builds and runs a tiny window program that LOGS what the Restart Manager
    sends to it, so the protocol facts in research.md are measured, not
    remembered from documentation.

.DESCRIPTION
    Feature 080, research R2. The dummy (rmdummy.exe, compiled here from the
    C# source below with the .NET Framework compiler that ships with Windows)
    opens one visible top-level window and writes every WM_QUERYENDSESSION,
    WM_ENDSESSION and WM_CLOSE it receives - with wParam, lParam and a
    millisecond timestamp - to <exe>.log. Its behaviour is chosen on the
    command line:

        agree-exit     answer TRUE, exit on WM_ENDSESSION            (well-behaved)
        agree-late N   answer TRUE, exit N seconds after WM_ENDSESSION
        agree-stay     answer TRUE, never exit
        slow-end N     answer TRUE, stay inside WM_ENDSESSION for N seconds (pumping
                       messages), then exit - shows when the WM_CLOSE really arrives
        refuse         answer FALSE
        query-exit     exit inside WM_QUERYENDSESSION (what Tandem Commander
                       did before feature 080)
        two            also open a second top-level window that logs what it gets
        register       additionally call RegisterApplicationRestart
                       (combine: "agree-exit register")

    Then run rm_probe.ps1 -ExePath <the dummy> [-Restart] and read the log.

.PARAMETER OutDir
    Where to build the dummy. Use a scratch directory.

.PARAMETER Mode
    Behaviour string passed to the dummy (see above).

.PARAMETER BuildOnly
    Compile and exit.

.NOTES
    Windows PowerShell 5.1 (uses Add-Type -OutputAssembly).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Mode = 'agree-exit',
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$exe = Join-Path $OutDir 'rmdummy.exe'

if (-not (Test-Path -LiteralPath $exe)) {
    $src = @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class RmDummy : Form
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern int RegisterApplicationRestart(string cmdLine, int flags);

    string log; string mode; int late;
    Timer timer;

    public void W(string s)
    {
        File.AppendAllText(log, DateTime.Now.ToString("HH:mm:ss.fff") + " pid " + System.Diagnostics.Process.GetCurrentProcess().Id + "  " + s + Environment.NewLine);
    }

    public RmDummy(string[] args)
    {
        log = Application.ExecutablePath + ".log";
        mode = string.Join(" ", args);
        Text = "rmdummy " + mode;
        Width = 360; Height = 120;
        W("START args='" + mode + "'");
        if (mode.Contains("register"))
        {
            // 1|2|8 = RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT
            int hr = RegisterApplicationRestart(mode + " restarted", 1 | 2 | 8);
            W("RegisterApplicationRestart -> 0x" + hr.ToString("X"));
        }
        foreach (string a in args) { int n; if (int.TryParse(a, out n)) late = n; }
    }

    protected override void WndProc(ref Message m)
    {
        const int WM_QUERYENDSESSION = 0x11, WM_ENDSESSION = 0x16, WM_CLOSE = 0x10;
        if (m.Msg == WM_QUERYENDSESSION)
        {
            W("WM_QUERYENDSESSION wParam=" + m.WParam + " lParam=0x" + m.LParam.ToInt64().ToString("X"));
            if (mode.Contains("query-exit")) { W("exiting inside the query"); m.Result = (IntPtr)1; Environment.Exit(0); }
            m.Result = mode.Contains("refuse") ? IntPtr.Zero : (IntPtr)1;
            return;
        }
        if (m.Msg == WM_ENDSESSION)
        {
            W("WM_ENDSESSION wParam=" + m.WParam + " lParam=0x" + m.LParam.ToInt64().ToString("X"));
            m.Result = IntPtr.Zero;
            if (m.WParam != IntPtr.Zero)
            {
                if (mode.Contains("slow-end"))
                {
                    // stay INSIDE the WM_ENDSESSION handler for 'late' seconds while pumping messages, the
                    // way a real program closes (wait windows, plug-in unload): does the WM_CLOSE arrive
                    // while we are still in here, or only after we return?
                    W("slow-end: staying inside WM_ENDSESSION for " + late + " s, pumping messages");
                    DateTime until = DateTime.Now.AddSeconds(late);
                    while (DateTime.Now < until) { Application.DoEvents(); System.Threading.Thread.Sleep(50); }
                    W("slow-end: leaving WM_ENDSESSION and exiting");
                    Environment.Exit(0);
                }
                if (mode.Contains("agree-exit")) { W("exiting on WM_ENDSESSION"); Environment.Exit(0); }
                if (mode.Contains("agree-late"))
                {
                    timer = new Timer(); timer.Interval = late * 1000;
                    timer.Tick += delegate { W("exiting late"); Environment.Exit(0); };
                    timer.Start();
                }
            }
            return;
        }
        if (m.Msg == WM_CLOSE)
        {
            W("WM_CLOSE (ignored - the dummy only ends the way its mode says)");
            return;
        }
        base.WndProc(ref m);
    }

    // "two": a second, unowned top-level window that only logs - shows which
    // messages the Restart Manager sends to windows other than the main one
    public class Second : Form
    {
        RmDummy owner;
        public Second(RmDummy o) { owner = o; Text = "rmdummy second window"; Width = 300; Height = 100; }
        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x11 || m.Msg == 0x16 || m.Msg == 0x10)
            {
                owner.W("  [second window] msg=0x" + m.Msg.ToString("X") + " wParam=" + m.WParam + " lParam=0x" + m.LParam.ToInt64().ToString("X"));
                if (m.Msg == 0x11) { m.Result = (IntPtr)1; return; }
                if (m.Msg == 0x10) return;
            }
            base.WndProc(ref m);
        }
    }

    [STAThread]
    public static void Main(string[] args)
    {
        RmDummy d = new RmDummy(args);
        if (d.mode.Contains("two")) { Second s2 = new Second(d); s2.Show(); }
        Application.Run(d);
    }
}
'@
    Add-Type -TypeDefinition $src -OutputAssembly $exe -OutputType WindowsApplication `
        -ReferencedAssemblies 'System.Windows.Forms', 'System.Drawing', 'System'
    Write-Host "Built $exe"
}
if ($BuildOnly) { exit 0 }

$p = Start-Process -FilePath $exe -ArgumentList $Mode -PassThru
Write-Host ("Started rmdummy pid {0} mode '{1}'; log: {2}.log" -f $p.Id, $Mode, $exe)
