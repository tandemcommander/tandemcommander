<#
.SYNOPSIS
    Feature 244 capture probe (quickstart V7): the panel idle and while a quick search runs, in the
    view modes Alt+2..Alt+6 (Brief, Detailed, Icons, Thumbnails, Tiles in the default templates) and
    in each built-in colour scheme (Salamander, Explorer, Norton, Navigator) and the Dark theme.

.DESCRIPTION
    Each scheme starts a fresh instance with the left panel on a fixture folder; per view mode the
    main window is captured (PrintWindow, PW_RENDERFULLCONTENT) idle and after typing "chat" into the
    left panel, then Esc. PNGs go to -CapDir as <scheme>_<view>_idle.png / _search.png. The colours
    are judged by a person (NOT DRIVEN here); the probe records that every capture was made and
    whether the searching capture differs from the idle one at all (pixel count).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$CapDir,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
Add-Type -AssemblyName System.Drawing
if (-not ('Cap244' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class Cap244
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    public static Bitmap Grab(IntPtr h)
    {
        RECT r; GetWindowRect(h, out r);
        int w = r.Right - r.Left, hh = r.Bottom - r.Top;
        var bmp = new Bitmap(w, hh, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
        using (var g = Graphics.FromImage(bmp))
        {
            IntPtr dc = g.GetHdc();
            PrintWindow(h, dc, 2);
            g.ReleaseHdc(dc);
        }
        return bmp;
    }
    public static int Diff(Bitmap a, Bitmap b)
    {
        if (a.Width != b.Width || a.Height != b.Height) return -1;
        int n = 0;
        for (int y = 0; y < a.Height; y += 2)
            for (int x = 0; x < a.Width; x += 2)
                if (a.GetPixel(x, y).ToArgb() != b.GetPixel(x, y).ToArgb()) n++;
        return n;
    }
}
'@
}
$Root = $TempRoot + '\tc244cap'
$RegBackup = $TempRoot + '\tc244cap_backup.reg'
[void][IO.Directory]::CreateDirectory($CapDir)

function Make-Fixture {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    $l = $Root + '\left'; $r = $Root + '\right'
    foreach ($d in @('2024_chatbot', 'alpha', 'chat_archive', 'photos')) { NewDir ($l + '\' + $d) }
    foreach ($f in @('chat.txt', 'beta.md', 'old.log', 'Report.PDF', 'notes.txt', 'chatter.cmd', 'setup.ini', 'image.bmp', 'data.csv', 'page.html', 'readme', 'script.ps1')) { WriteFile ($l + '\' + $f) 'x' }
    NewDir $r
    return [pscustomobject]@{ Left = $l; Right = $r }
}
function Start-Cap($F) {
    $a = @('-t', 'T244C', '-l', ('"{0}"' -f $F.Left), '-r', ('"{0}"' -f $F.Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'no main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Type-Text([int]$Id, [string]$Text) {
    $l = Get-LeftList $Id
    foreach ($c in $Text.ToCharArray()) { [void][Drv098f]::Send($l, 0x0102, [int]$c, 1, 30000) }
    Start-Sleep -Milliseconds 400
}

$schemes = @(
    @{ Name = 'salamander'; Scheme = 0; Theme = 0 },
    @{ Name = 'explorer'; Scheme = 1; Theme = 0 },
    @{ Name = 'norton'; Scheme = 2; Theme = 0 },
    @{ Name = 'navigator'; Scheme = 3; Theme = 0 },
    @{ Name = 'dark'; Scheme = 0; Theme = 1 }
)
$views = @(@{ N = 'brief'; C = 2981 }, @{ N = 'detailed'; C = 2982 }, @{ N = 'icons'; C = 2983 }, @{ N = 'thumbnails'; C = 2984 }, @{ N = 'tiles'; C = 2985 })

$existed = Backup-Reg $RegBackup
Out ("Feature 244 capture probe; exe {0}; registry backup {1} (existed {2})" -f $Exe, $RegBackup, $existed)
try {
    $F = Make-Fixture
    foreach ($s in $schemes) {
        Set-Config
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Quick Search Enter Alt' /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Quick Search Filter' /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Theme Mode' /t REG_DWORD /d $s.Theme /f | Out-Null
        & reg.exe add "$RegKey\0.1\Colors" /v 'Color Scheme' /t REG_DWORD /d $s.Scheme /f | Out-Null
        $before = Reports; $id = 0
        try {
            $id = Start-Cap $F
            foreach ($v in $views) {
                Post-Cmd (Get-Main $id) $v.C; Start-Sleep -Milliseconds 1500
                $idle = [Cap244]::Grab((Get-Main $id))
                Type-Text $id 'chat'; Start-Sleep -Milliseconds 800
                $srch = [Cap244]::Grab((Get-Main $id))
                $base = Join-Path $CapDir ('{0}_{1}' -f $s.Name, $v.N)
                $idle.Save($base + '_idle.png', [Drawing.Imaging.ImageFormat]::Png)
                $srch.Save($base + '_search.png', [Drawing.Imaging.ImageFormat]::Png)
                $d = [Cap244]::Diff($idle, $srch)
                Row $s.Name $v.N $(if ($d -gt 0) { 'CAPTURED' } else { 'FAIL' }) ("{0}x{1}; pixels differing (every 2nd) {2}" -f $idle.Width, $idle.Height, $d)
                $idle.Dispose(); $srch.Dispose()
                Key $id 0x1B; Start-Sleep -Milliseconds 500
            }
        }
        catch { Row $s.Name 'ERROR' 'FAIL' ($_.Exception.Message) }
        finally { if ($id) { $fatal = Fatal-Win $id; End-Row $s.Name $id $fatal $before } }
    }
}
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Kill-Mine $p } }
    $ok = Restore-Reg $RegBackup $existed
    if (-not $ok) { Out 'REGISTRY RESTORE FAILED' }
    $fails = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("ROWS {0}; FAIL {1}" -f $script:Rows.Count, $fails)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, $Utf8) }
}
exit $fails
