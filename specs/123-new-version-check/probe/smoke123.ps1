<#
.SYNOPSIS
    Feature 123 smoke run: one start of the Debug build against one fixture of updserver.py;
    prints the top-level windows of the program after the check, their texts, and the stored
    state. A development aid, not the acceptance probe (that is updcheck_probe.ps1).

    MUST run through tools\run_on_hidden_desktop.ps1. Backs up and restores the whole registry
    key of the product. Debug builds only (uses the TC_UPDATECHECK_* seam).

.PARAMETER Exe      tandemcommander.exe of a Debug build
.PARAMETER Fixture  fixture name of updserver.py (default newer)
.PARAMETER Pretend  the version the program pretends to be (default 0.1.8)
.PARAMETER Manual   post the Help command instead of relying on the start-up check
.PARAMETER Shot     optional PNG file: a capture of the notification window (PrintWindow)
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Fixture = 'newer',
    [string]$Pretend = '0.1.8',
    [switch]$Manual,
    [int]$Cmd = 0,
    [string]$Lang = 'english',
    [switch]$Dark,
    [switch]$Real,   # no seam: the real endpoint (api.github.com) and the real version
    [string]$CmdShot = '',
    [string]$Shot = '',
    [int]$Port = 8123,
    [int]$WaitSeconds = 8
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Write-Host 'NOT RUN: a tandemcommander.exe is running'; exit 3 }

if (-not ('Shot123' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class Shot123
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr GetPropW(IntPtr h, string name);
    public static bool Capture(IntPtr h, string file)
    {
        RECT r; if (!GetWindowRect(h, out r)) return false;
        int w = r.R - r.L, hh = r.B - r.T; if (w <= 0 || hh <= 0) return false;
        using (var bmp = new Bitmap(w, hh))
        {
            bool ok;
            using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); ok = PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
            bmp.Save(file, System.Drawing.Imaging.ImageFormat.Png);
            return ok;
        }
    }
}
'@
}

$work = Join-Path $env:TEMP 'tc123_smoke'
[void][IO.Directory]::CreateDirectory($work)
[void][IO.Directory]::CreateDirectory($StartDir)
$regFile = Join-Path $work 'reg_backup.reg'
$srvLog = Join-Path $work 'requests.log'
$openLog = Join-Path $work 'opened.log'
Remove-Item -LiteralPath $srvLog, $openLog -Force -ErrorAction SilentlyContinue

$existed = Backup-Reg $regFile
$srv = $null
$id = 0
try {
    Set-Config
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d "$Lang.slg" /f | Out-Null
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Theme Mode' /t REG_DWORD /d $(if ($Dark) { 1 } else { 0 }) /f | Out-Null
    & cmd.exe /c "reg delete `"$RegKey\0.1\Update Check`" /f >nul 2>&1"
    $srv = Start-Process -FilePath python -ArgumentList @((Join-Path $PSScriptRoot 'updserver.py'), '--port', $Port, '--log', $srvLog) -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 1200
    if (-not $Real) {
        $env:TC_UPDATECHECK_URL = "http://127.0.0.1:$Port/latest/$Fixture"
        $env:TC_UPDATECHECK_PRETEND_VERSION = $Pretend
    }
    $env:TC_UPDATECHECK_OPENLOG = $openLog
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $id = Start-Tc $StartDir
    Out ("started pid {0} after {1:N1} s" -f $id, $sw.Elapsed.TotalSeconds)
    if ($Manual) { Post-Cmd (Get-Main $id) 2217 }
    Start-Sleep -Seconds $WaitSeconds
    if ($Cmd) {
        Post-Cmd (Get-Main $id) $Cmd; Start-Sleep -Seconds 3
        foreach ($h in (Get-Tops $id)) { if ([Drv098f]::Cls($h) -ne $MainClass -and [Shot123]::GetPropW($h, 'TandemCommander.UpdateNotice') -eq [IntPtr]::Zero) {
            Out ('CMDWINDOW ' + (WinDesc $h))
            foreach ($k in [Drv098f]::Kids($h)) { Out ("   ctl {0,5} {1,-8} vis={2} '{3}'" -f [Drv098f]::GetDlgCtrlID($k), [Drv098f]::Cls($k), [Drv098f]::IsWindowVisible($k), (Esc ([Drv098f]::Txt($k)))) }
            if ($CmdShot) { Out ('   shot: ' + [Shot123]::Capture($h, $CmdShot)) }
        } }
    }
    foreach ($h in (Get-Tops $id)) {
        $isNotice = [Shot123]::GetPropW($h, 'TandemCommander.UpdateNotice') -ne [IntPtr]::Zero
        Out ("WINDOW notice={0} {1}" -f $isNotice, (WinDesc $h))
        if ($isNotice) {
            foreach ($k in [Drv098f]::Kids($h)) { Out ("   ctl {0,5} {1,-8} vis={2} '{3}'" -f [Drv098f]::GetDlgCtrlID($k), [Drv098f]::Cls($k), [Drv098f]::IsWindowVisible($k), (Esc ([Drv098f]::Txt($k)))) }
            if ($Shot) { Out ("   shot {0}: {1}" -f $Shot, [Shot123]::Capture($h, $Shot)) }
        }
    }
    Out '--- stored state'
    & cmd.exe /c "reg query `"$RegKey\0.1\Update Check`" 2>&1" | ForEach-Object { if ($_) { Out ("   " + $_) } }
    Out '--- requests'
    if (Test-Path -LiteralPath $srvLog) { Get-Content -LiteralPath $srvLog | ForEach-Object { Out ("   " + $_) } } else { Out '   (none)' }
    $fatal = Fatal-Win $id
    if ($fatal) { Out ("FATAL WINDOW: " + $fatal) }
    $swx = [Diagnostics.Stopwatch]::StartNew()
    Stop-Tc $id
    Out ("exit after {0:N1} s, code {1}" -f $swx.Elapsed.TotalSeconds, (ExitCodeOf $id))
}
finally {
    if ($id -and (Test-Alive $id)) { Kill-Mine $id }
    if ($srv -and -not $srv.HasExited) { Stop-Process -Id $srv.Id -Force }
    Remove-Item Env:\TC_UPDATECHECK_URL, Env:\TC_UPDATECHECK_PRETEND_VERSION, Env:\TC_UPDATECHECK_OPENLOG -ErrorAction SilentlyContinue
    [void](Restore-Reg $regFile $existed)
}
