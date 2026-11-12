# Measurement for backlog item tmavy-motiv (GitHub #25), on main before any change:
# in the Dark theme, how do checkbox labels paint in the core's Configuration and in PictView's
# settings, and what does PictView's toolbar look like. MUST run through tools\run_on_hidden_desktop.ps1.
# Registry exported, restored and verified (fix_probe_lib Backup-Reg / Restore-Reg).
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Exe, [Parameter(Mandatory = $true)][string]$Repo,
      [Parameter(Mandatory = $true)][string]$OutFile, [Parameter(Mandatory = $true)][string]$CapDir,
      [Parameter(Mandatory = $true)][string]$Image, [int]$Theme = 1)
$ErrorActionPreference = 'Stop'
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $Repo 'specs\416-fluent-icon-set\probe\capture416_lib.ps1')
$Root = $TempRoot + '\tc427measure'
$StartDir = $Root + '\start'
$Left = $Root + '\left'
$CfgKey = "$RegKey\Settings\Configuration"
[void][IO.Directory]::CreateDirectory($CapDir)

if (-not ('Lbl427' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Lbl427
{
    [DllImport("user32.dll")] public static extern int GetWindowLongW(IntPtr h, int i);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", SetLastError = true)] static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
    // a key with Ctrl+Shift for the target's thread (the method of probe 118)
    public static string CtrlShiftKey(IntPtr target, int vk)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed";
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone(); k[0x10] = k[0xA0] = 0x80; k[0x11] = k[0xA2] = 0x80;
            SetKeyboardState(k);
            PostMessageW(target, 0x0100, (IntPtr)vk, (IntPtr)1);
            IntPtr r; SendMessageTimeoutW(target, 0, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r);
            System.Threading.Thread.Sleep(300);
            return "ok";
        }
        finally { SetKeyboardState(saved); PostMessageW(target, 0x0101, (IntPtr)vk, unchecked((IntPtr)0xC0000001)); AttachThreadInput(me, tid, false); }
    }
    static double Lum(int c)
    {
        Func<int, double> f = v => { double s = v / 255.0; return s <= 0.03928 ? s / 12.92 : Math.Pow((s + 0.055) / 1.055, 2.4); };
        return 0.2126 * f((c >> 16) & 255) + 0.7152 * f((c >> 8) & 255) + 0.0722 * f(c & 255);
    }
    public static double Contrast(int a, int b) { double x = Lum(a), y = Lum(b); return (Math.Max(x, y) + 0.05) / (Math.Min(x, y) + 0.05); }
    // a checkbox's label: bg = most frequent colour right of the glyph; ink = the pixel that differs most from it
    public static string Label(Bitmap b, int glyph)
    {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
        int[] px = new int[b.Width * b.Height];
        for (int y = 0; y < b.Height; y++) Marshal.Copy(IntPtr.Add(d.Scan0, y * d.Stride), px, y * b.Width, b.Width);
        b.UnlockBits(d);
        var h = new Dictionary<int, int>();
        for (int y = 0; y < b.Height; y++) for (int x = glyph; x < b.Width; x++) { int c = px[y * b.Width + x] & 0xFFFFFF; int v; h.TryGetValue(c, out v); h[c] = v + 1; }
        int bg = 0, top = -1; foreach (var kv in h) if (kv.Value > top) { top = kv.Value; bg = kv.Key; }
        int ink = bg; double best = 1; int inkN = 0;
        foreach (var kv in h) { double c = Contrast(kv.Key, bg); if (c > 1.5) inkN += kv.Value; if (c > best) { best = c; ink = kv.Key; } }
        string dir = Lum(ink) > Lum(bg) ? "light-on-dark" : "dark-on-light";
        return string.Format("bg #{0:X6} ink #{1:X6} contrast {2:0.00} {3} inkpx {4}", bg, ink, best, dir, inkN);
    }
}
'@
}

function Checkboxes([IntPtr]$Top) {
    $all = @([Cap416]::Kids($Top) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::Cls($_) -eq 'Button' })
    return @($all | Where-Object { $t = [Lbl427]::GetWindowLongW($_, -16) -band 0xF; $t -eq 2 -or $t -eq 3 -or $t -eq 5 -or $t -eq 6 })
}
function Measure-Labels([IntPtr]$Top, [string]$Tag) {
    [void][Drv098f]::Send($Top, 0, 0, 0, 10000)
    Start-Sleep -Milliseconds 600
    $cap = [Cap416]::Capture($Top, $true)
    Save-Png $cap (Join-Path $CapDir ("{0}.png" -f $Tag))
    $n = 0; $dark = 0
    foreach ($c in (Checkboxes $Top)) {
        $crop = [Cap416]::Crop($cap, $Top, $c)
        $style = [Lbl427]::GetWindowLongW($c, -16)
        $info = [Lbl427]::Label($crop, 18)
        Out ("{0}: id {1} type {2} '{3}' -> {4}" -f $Tag, [Cap416]::GetDlgCtrlID($c), ($style -band 0xF), (Tail ([Cap416]::Txt($c)) 40), $info)
        $n++; if ($info -match 'dark-on-light' -and $info -match 'bg #([0-9A-F]{6})' -and [Convert]::ToInt32($Matches[1], 16) -lt 0x606060) { $dark++ }
        $crop.Dispose()
    }
    $cap.Dispose()
    Out ("{0}: {1} checkbox/radio labels, {2} dark ink on a dark background" -f $Tag, $n, $dark)
}

# File Comparator Ctrl+Shift+C, Batch Rename Ctrl+Shift+R for this session (the method of probe 118;
# the whole key is restored afterwards)
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\Settings\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    $map = @(@{ Dll = 'filecomp\.spl$'; Id = 1; Key = 0x10343 }, @{ Dll = 'renamer\.spl$'; Id = 1; Key = 0x10352 })
    $notes = @()
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll) { continue }
        foreach ($m in $map) {
            if ($dll -notmatch $m.Dll) { continue }
            $menu = Join-Path $k.PSPath 'Menu'
            if (-not (Test-Path $menu)) { $notes += ("{0}: no Menu key" -f $dll); continue }
            $set = 0
            foreach ($mi in @(Get-ChildItem $menu)) {
                if ((Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID -eq $m.Id) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value $m.Key -Type DWord; $set++ }
            }
            $notes += ("{0} id {1}: {2}" -f (Split-Path $dll -Leaf), $m.Id, $set)
        }
    }
    return ($notes -join '; ')
}
function Open-ByKey([int]$Id, [int]$Vk, [double]$Seconds = 15) {
    $known = Get-Tops $Id
    $note = [Lbl427]::CtrlShiftKey((Get-LeftList $Id), $Vk)
    $h = Wait-NewWin $Id $known $Seconds
    Out ("Ctrl+Shift+{0}: {1}, window {2}" -f [char]$Vk, $note, $(if ($h -ne [IntPtr]::Zero) { WinDesc $h } else { 'none' }))
    return $h
}
function Shot([IntPtr]$H, [string]$Tag) {
    [void][Drv098f]::Send($H, 0, 0, 0, 10000); Start-Sleep -Milliseconds 800
    $c = [Cap416]::Capture($H, $true); Save-Png $c (Join-Path $CapDir ("{0}.png" -f $Tag))
    Out ("{0}: {1}; light-grey F0F0F0 px {2}" -f $Tag, [Cap416]::Stats($c), [Cap416]::CountColor($c, 0xF0F0F0, 2)); $c.Dispose()
}

$backup = Join-Path $env:TEMP 'tc427measure_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Left
    Copy-Item -LiteralPath $Image -Destination (Join-Path $Left 'image.png')
    Copy-Item -LiteralPath $Image -Destination (Join-Path $Left 'image2.png')
    Set-Config
    Out ("hot keys: {0}" -f (Set-HotKeys))
    & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
    & reg.exe add $CfgKey /v 'Toolbar Icon Set' /t REG_DWORD /d 0 /f | Out-Null
    Out ("dark_measure on {0}, Theme Mode {1}, OS {2}" -f $Exe, $Theme, [Environment]::OSVersion.Version)
    $id = Start-Tc $Left
    [void](Serve $id 6)
    # A) the core's Configuration (926)
    $cfg = Open-ByCmd $id 926
    if ($cfg -eq [IntPtr]::Zero) { Out 'core Configuration did not open' } else { Measure-Labels $cfg 'core_config'; Close-Win $cfg }
    Start-Sleep -Milliseconds 800
    # B) PictView: F3 on image.png (the second row after ..), then CMD_CFG (112) in the viewer
    # focus image.png (Change Directory to the file's full path), then View (742) - the way probes 105/111/120 do
    [void](Do-ChangeDir $id (Join-Path $Left 'image.png')); [void](Serve $id 8)
    [void][Drv098f]::Send((Get-Main $id), 0, 0, 0, 20000)
    $known = Get-Tops $id
    Out ("tops before View: {0}" -f (($known | ForEach-Object { WinDesc $_ }) -join ' | '))
    Post-Cmd (Get-Main $id) 742
    $viewer = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and $viewer -eq [IntPtr]::Zero) {
        $w = @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne '#32770' }) | Select-Object -First 1
        if ($w) { $viewer = $w } else { Start-Sleep -Milliseconds 200 }
    }
    Out ("tops after View: {0}" -f ((Get-Tops $id | ForEach-Object { WinDesc $_ }) -join ' | '))
    if ($viewer -eq [IntPtr]::Zero) { throw 'the PictView viewer did not open' }
    Start-Sleep -Milliseconds 2500
    Out ("viewer: {0}" -f (WinDesc $viewer))
    $vcap = [Cap416]::Capture($viewer, $true); Save-Png $vcap (Join-Path $CapDir 'pictview_viewer.png')
    foreach ($tb in (Get-Desc $viewer 'ToolbarWindow32')) {
        $b = [Cap416]::Crop($vcap, $viewer, $tb); Save-Png $b (Join-Path $CapDir ("pictview_toolbar_{0}.png" -f [Cap416]::GetDlgCtrlID($tb))); Out ("pictview toolbar {0}: {1}" -f [Cap416]::GetDlgCtrlID($tb), [Cap416]::Stats($b)); $b.Dispose()
    }
    $vcap.Dispose()
    $known = Get-Tops $id
    Post-Cmd $viewer 112
    $pv = Wait-NewWin $id $known 15
    if ($pv -eq [IntPtr]::Zero) { throw 'PictView settings did not open' }
    Out ("pictview settings: {0}" -f (WinDesc $pv))
    for ($page = 0; $page -lt 5; $page++) {
        [void][Cap416]::Send($pv, 0x0465, [IntPtr]$page, [IntPtr]::Zero)   # PSM_SETCURSEL
        Start-Sleep -Milliseconds 700
        Measure-Labels $pv ("pictview_page{0}" -f $page)
    }
    Close-Win $pv
    [void][Drv098f]::PostMessageW($viewer, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 1500
    # C) Batch Rename on the selected files (Ctrl+Shift+R)
    Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800   # select all
    $rn = Open-ByKey $id 0x52
    if ($rn -ne [IntPtr]::Zero) { Start-Sleep -Milliseconds 1500; Measure-Labels $rn 'renamer'; Shot $rn 'renamer_full'; [void][Drv098f]::PostMessageW($rn, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 1000 }
    foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Out ("left open: {0}" -f (WinDesc $h)) }
    # D) File Comparator on the two selected files (Ctrl+Shift+C)
    Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
    $fc = Open-ByKey $id 0x43
    if ($fc -ne [IntPtr]::Zero -and [Drv098f]::Cls($fc) -eq '#32770') {
        Measure-Labels $fc 'filecomp_dialog'; Shot $fc 'filecomp_dialog_full'
        $known = Get-Tops $id; Click-Ok $fc
        $fcw = Wait-NewWin $id $known 20
        if ($fcw -ne [IntPtr]::Zero) { Start-Sleep -Milliseconds 2500; Out ("filecomp window: {0}" -f (WinDesc $fcw)); Shot $fcw 'filecomp_window' }
    }
    Stop-Tc $id
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    Out ("registry restored+identical: {0}" -f $restored)
    [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding))
}
