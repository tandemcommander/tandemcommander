<#
.SYNOPSIS
    Feature 244 capture probe: the Configuration > Panels page (new checkbox "Quick search finds
    text anywhere in names and shows only the matches", the page's controls moved to make room)
    in every enabled language, so that clipped text or overlapping controls can be seen.

.DESCRIPTION
    Per language: Language = <lang>.slg, Last Focused Page = 1 (Panels), start, post
    WM_USER_CONFIGURATION, capture the dialog with PrintWindow to -CapDir\cfg_<lang>.png, Cancel.
    Also records the checkbox's text, rectangle and checked state (BM_GETCHECK) - default ON.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$CapDir,
    [string]$OutFile,
    [switch]$NoFilterValue          # delete 'Quick Search Filter' first: the default must be ON
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
Add-Type -AssemblyName System.Drawing
if (-not ('CapCfg244' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class CapCfg244
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    public static Bitmap Grab(IntPtr h)
    {
        RECT r; GetWindowRect(h, out r);
        var bmp = new Bitmap(r.Right - r.Left, r.Bottom - r.Top, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
        using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
        return bmp;
    }
}
'@
}
$Root = $TempRoot + '\tc244cfg'
$RegBackup = $TempRoot + '\tc244cfg_backup.reg'
[void][IO.Directory]::CreateDirectory($CapDir)
$langs = @('english', 'czech', 'german', 'french', 'dutch', 'hungarian', 'romanian', 'slovak', 'spanish')
$langDir = Join-Path (Split-Path -Parent $Exe) 'lang'

$existed = Backup-Reg $RegBackup
Out ("Feature 244 Configuration page probe; exe {0}; backup {1} (existed {2})" -f $Exe, $RegBackup, $existed)
try {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    NewDir ($Root + '\left'); NewDir ($Root + '\right')
    foreach ($lang in $langs) {
        if (-not (Test-Path -LiteralPath (Join-Path $langDir ($lang + '.slg')))) { Row $lang 'PAGE' 'NOT DRIVEN' 'no language module'; continue }
        Set-Config
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d ($lang + '.slg') /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Last Focused Page' /t REG_DWORD /d 1 /f | Out-Null
        if ($NoFilterValue) { & cmd.exe /c "reg delete `"$RegKey\0.1\Configuration`" /v `"Quick Search Filter`" /f >nul 2>&1" }
        $before = Reports; $id = 0
        try {
            $a = @('-t', 'T244G', '-l', ('"{0}\left"' -f $Root), '-r', ('"{0}\right"' -f $Root), '-p', '1')
            $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
            [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 60 -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
            Start-Sleep -Milliseconds 1500
            $known = Get-Tops $id
            [void][Drv098f]::PostMessageW((Get-Main $id), 0x8000 + 115, [IntPtr]::Zero, [IntPtr]::Zero)
            $dlg = Wait-NewWin $id $known 15
            if ($dlg -eq [IntPtr]::Zero) { Row $lang 'PAGE' 'FAIL' 'no Configuration dialog'; continue }
            Start-Sleep -Milliseconds 1200
            $bmp = [CapCfg244]::Grab($dlg)
            $bmp.Save((Join-Path $CapDir ('cfg_' + $lang + '.png')), [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
            $cb = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 307 -and [Drv098f]::Cls($_) -eq 'Button' }) | Select-Object -First 1
            if (-not $cb) { Row $lang 'PAGE' 'FAIL' 'checkbox 307 not found'; Close-Win $dlg; continue }
            $chk = 0; [void][Drv098f]::Send($cb, 0x00F0, 0, 0, 5000)
            $res = [IntPtr]::Zero; [void][Drv098f]::SendMessageTimeoutW($cb, 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res); $chk = $res.ToInt64()
            $r = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($cb, [ref]$r)
            Row $lang 'PAGE' $(if ($chk -eq 1) { 'PASS' } else { 'FAIL' }) ("checked {0}; text '{1}'; {2}x{3} px" -f $chk, (Esc ([Drv098f]::Txt($cb))), ($r.Right - $r.Left), ($r.Bottom - $r.Top))
            Close-Win $dlg
        }
        catch { Row $lang 'ERROR' 'FAIL' ($_.Exception.Message) }
        finally { if ($id) { $fatal = Fatal-Win $id; End-Row $lang $id $fatal $before } }
    }
}
finally {
    foreach ($q in @($Started)) { if (Test-Alive $q) { Kill-Mine $q } }
    $ok = Restore-Reg $RegBackup $existed
    if (-not $ok) { Out 'REGISTRY RESTORE FAILED' }
    $fails = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("ROWS {0}; FAIL {1}" -f $script:Rows.Count, $fails)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, $Utf8) }
}
exit $fails
