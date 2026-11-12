# Feature 427 probe (backlog item tmavy-motiv, GitHub #25): plug-in toolbars, File Comparator's
# chrome and plug-in checkbox labels in the Dark theme; the Default theme unchanged.
# MUST run through tools\run_on_hidden_desktop.ps1 (it starts the program and drives its windows).
# The registry key is exported first, restored afterwards and verified (fix_probe_lib Backup-Reg /
# Restore-Reg); the program is started from a fixture under %TEMP% only.
#
# Rows, per theme (DARK, DEFAULT):
#   PV-TOOLBAR  PictView viewer toolbar: glyph pixels darker than the strip (Dark: < 10 % of before)
#   FC-TOOLBAR  File Comparator toolbar: the same
#   FC-GREY     File Comparator: light-grey (#F0F0F0 +-2) pixels outside its two text views
#               (Dark: < 1 % of before)
#   PV-LABELS   PictView settings, all five pages: every checkbox label contrast >= 4.5
#   RN-LABELS   Batch Rename: every checkbox label contrast >= 4.5
#   DEFAULT-SAME (after only) the Default theme's toolbar and File Comparator captures equal the
#               before run's
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Exe, [Parameter(Mandatory = $true)][string]$Repo,
      [Parameter(Mandatory = $true)][string]$Label)
$ErrorActionPreference = 'Stop'
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
$Repo = [IO.Path]::GetFullPath($Repo)
$Exe = [IO.Path]::GetFullPath($Exe)
. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $Repo 'specs\416-fluent-icon-set\probe\capture416_lib.ps1')
$ProbeDir = Join-Path $Repo 'specs\427-dark-plugin-toolbars\probe'
$CapDir = Join-Path $ProbeDir ("captures_{0}" -f $Label)
$BeforeDir = Join-Path $ProbeDir 'captures_before'
$OutFile = Join-Path $ProbeDir ("result_{0}_rows.txt" -f $Label)
$Root = $TempRoot + '\tc427probe'
$StartDir = $Root + '\start'
$Left = $Root + '\left'
$CfgKey = "$RegKey\Settings\Configuration"
$Image = Join-Path $Repo 'backlog\items\tmavy-motiv\evidence\issue25-pictview-settings-advanced.png'
if (-not (Test-Path -LiteralPath $Image)) { $Image = Join-Path $ProbeDir 'captures_measure\pictview_page4.png' }
[void][IO.Directory]::CreateDirectory($CapDir)

if (-not ('Px427' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Px427
{
    [DllImport("user32.dll")] public static extern int GetWindowLongW(IntPtr h, int i);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
    public static int[] Px(Bitmap b)
    {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
        int[] px = new int[b.Width * b.Height];
        for (int y = 0; y < b.Height; y++) Marshal.Copy(IntPtr.Add(d.Scan0, y * d.Stride), px, y * b.Width, b.Width);
        b.UnlockBits(d);
        for (int i = 0; i < px.Length; i++) px[i] &= 0xFFFFFF;
        return px;
    }
    static double Lum(int c)
    {
        Func<int, double> f = v => { double s = v / 255.0; return s <= 0.03928 ? s / 12.92 : Math.Pow((s + 0.055) / 1.055, 2.4); };
        return 0.2126 * f((c >> 16) & 255) + 0.7152 * f((c >> 8) & 255) + 0.0722 * f(c & 255);
    }
    static double Contrast(int a, int b) { double x = Lum(a), y = Lum(b); return (Math.Max(x, y) + 0.05) / (Math.Min(x, y) + 0.05); }
    static int Mode(int[] px, int from, int width, int height, int stride)
    {
        var h = new Dictionary<int, int>();
        for (int y = 0; y < height; y++) for (int x = from; x < width; x++) { int c = px[y * stride + x]; int v; h.TryGetValue(c, out v); h[c] = v + 1; }
        int bg = 0, top = -1; foreach (var kv in h) if (kv.Value > top) { top = kv.Value; bg = kv.Key; }
        return bg;
    }
    // a checkbox label: the highest contrast of a pixel right of the glyph to the background
    public static double LabelContrast(Bitmap b, int glyph, out int bg, out int ink)
    {
        int[] px = Px(b);
        bg = Mode(px, glyph, b.Width, b.Height, b.Width);
        ink = bg; double best = 1;
        for (int y = 0; y < b.Height; y++) for (int x = glyph; x < b.Width; x++) { int c = px[y * b.Width + x]; double k = Contrast(c, bg); if (k > best) { best = k; ink = c; } }
        return best;
    }
    // toolbar glyphs: pixels clearly darker than the strip's background (invisible on a dark strip)
    public static int DarkerThanStrip(Bitmap b, out int bg)
    {
        int[] px = Px(b);
        bg = Mode(px, 0, b.Width, b.Height, b.Width);
        double lb = Lum(bg); int n = 0;
        foreach (int c in px) if (c != bg && Lum(c) < lb && Contrast(c, bg) > 1.15) n++;
        return n;
    }
    public static int Grey(Bitmap b, int x0, int y0, int x1, int y1)
    {
        int[] px = Px(b); int n = 0;
        for (int y = Math.Max(0, y0); y < Math.Min(b.Height, y1); y++)
            for (int x = Math.Max(0, x0); x < Math.Min(b.Width, x1); x++)
            {
                int c = px[y * b.Width + x], r = (c >> 16) & 255, g = (c >> 8) & 255, bb = c & 255;
                if (Math.Abs(r - 0xF0) <= 2 && Math.Abs(g - 0xF0) <= 2 && Math.Abs(bb - 0xF0) <= 2) n++;
            }
        return n;
    }
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
}
'@
}

function Checkboxes([IntPtr]$Top) {
    return @([Cap416]::Kids($Top) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::Cls($_) -eq 'Button' -and (@(2, 3, 5, 6) -contains ([Px427]::GetWindowLongW($_, -16) -band 0xF)) })
}
# the lowest label contrast of a window's checkboxes; details into the log
function Labels([IntPtr]$Top, [string]$Tag) {
    [void][Drv098f]::Send($Top, 0, 0, 0, 10000); Start-Sleep -Milliseconds 700
    $cap = [Cap416]::Capture($Top, $true); Save-Png $cap (Join-Path $CapDir ("{0}.png" -f $Tag))
    $min = 99.0; $n = 0
    foreach ($c in (Checkboxes $Top)) {
        $crop = [Cap416]::Crop($cap, $Top, $c); $bg = 0; $ink = 0
        $k = [Px427]::LabelContrast($crop, 18, [ref]$bg, [ref]$ink)
        Out ("  {0}: id {1} '{2}' bg #{3:X6} ink #{4:X6} contrast {5:0.00}" -f $Tag, [Cap416]::GetDlgCtrlID($c), (Tail ([Cap416]::Txt($c)) 36), $bg, $ink, $k)
        if ($k -lt $min) { $min = $k }; $n++; $crop.Dispose()
    }
    $cap.Dispose()
    return @{ N = $n; Min = $min }
}
# a toolbar's glyph pixels darker than its strip; the crop saved
function Toolbar-Dark([IntPtr]$Top, [IntPtr]$Tb, [string]$Tag) {
    $cap = [Cap416]::Capture($Top, $true)
    $crop = [Cap416]::Crop($cap, $Top, $Tb)
    Save-Png $crop (Join-Path $CapDir ("{0}.png" -f $Tag))
    $bg = 0; $n = [Px427]::DarkerThanStrip($crop, [ref]$bg)
    $crop.Dispose(); $cap.Dispose()
    return @{ N = $n; Bg = $bg }
}
function Same-As-Before([string]$Name) {
    $a = Join-Path $BeforeDir $Name; $b = Join-Path $CapDir $Name
    if (-not (Test-Path $a) -or -not (Test-Path $b)) { return 'missing' }
    $x = New-Object Drawing.Bitmap $a; $y = New-Object Drawing.Bitmap $b
    try { return [Cap416]::Diff($x, $y) } finally { $x.Dispose(); $y.Dispose() }
}
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
            if (-not (Test-Path $menu)) { continue }
            foreach ($mi in @(Get-ChildItem $menu)) {
                if ((Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID -eq $m.Id) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value $m.Key -Type DWord; $notes += (Split-Path $dll -Leaf) }
            }
        }
    }
    return ($notes -join ', ')
}
function Open-ByKey([int]$Id, [int]$Vk, [double]$Seconds = 15) {
    $known = Get-Tops $Id
    [void][Px427]::CtrlShiftKey((Get-LeftList $Id), $Vk)
    return (Wait-NewWin $Id $known $Seconds)
}
function Open-Viewer([int]$Id) {
    [void](Do-ChangeDir $Id (Join-Path $Left 'image.png')); [void](Serve $Id 8)
    [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000)
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 742
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne '#32770' }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 2500; return $w }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}

function Run-Theme([int]$Theme) {
    $t = if ($Theme -eq 1) { 'DARK' } else { 'DEFAULT' }
    & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
    $id = Start-Tc $Left
    [void](Serve $id 6)
    try {
        # PictView viewer: its toolbar (the widest visible child whose class names a tool bar)
        $viewer = Open-Viewer $id
        if ($viewer -eq [IntPtr]::Zero) { Row $t 'PV-TOOLBAR' 'FAIL' 'the viewer did not open'; return }
        # the viewer's rebar holds the menu bar and the toolbar (both core GUI windows): the lower one
        $rb = @(Get-Desc $viewer 'ReBarWindow32') | Select-Object -First 1
        $tbs = @()
        if ($rb) { $bars = @(Get-Desc $rb 'WinLib Universal Window2'); if ($bars.Count -ge 2) { $tbs = @($bars[$bars.Count - 1]) } }
        if ($tbs.Count -eq 0) { Out ("  viewer children: {0}" -f ((@([Cap416]::Kids($viewer)) | ForEach-Object { [Cap416]::Cls($_) } | Sort-Object -Unique) -join ', ')); Row $t 'PV-TOOLBAR' 'FAIL' 'no toolbar found' }
        else {
            $r = Toolbar-Dark $viewer $tbs[0] ("pv_toolbar_{0}" -f $t)
            $script:Num["PV-TOOLBAR $t"] = $r.N
            Row $t 'PV-TOOLBAR' 'INFO' ("class {0}; strip #{1:X6}; glyph pixels darker than the strip: {2}" -f [Cap416]::Cls($tbs[0]), $r.Bg, $r.N)
        }
        # PictView settings (CMD_CFG 112 in the viewer), five pages
        $known = Get-Tops $id
        Post-Cmd $viewer 112
        $pv = Wait-NewWin $id $known 15
        if ($pv -eq [IntPtr]::Zero) { Row $t 'PV-LABELS' 'FAIL' 'PictView settings did not open' }
        else {
            $min = 99.0; $n = 0
            for ($page = 0; $page -lt 5; $page++) {
                [void][Cap416]::Send($pv, 0x0465, [IntPtr]$page, [IntPtr]::Zero); Start-Sleep -Milliseconds 600
                $r = Labels $pv ("pv_page{0}_{1}" -f $page, $t); $n += $r.N; if ($r.Min -lt $min) { $min = $r.Min }
            }
            $v = if ($Theme -eq 1) { V ($n -ge 6 -and $min -ge 4.5) } else { 'INFO' }
            Row $t 'PV-LABELS' $v ("{0} checkboxes on 5 pages, lowest label contrast {1:0.00}" -f $n, $min)
            Close-Win $pv
        }
        [void][Drv098f]::PostMessageW($viewer, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 1500
        # Batch Rename (Ctrl+Shift+R) on the two files
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        $rn = Open-ByKey $id 0x52
        if ($rn -eq [IntPtr]::Zero) { Row $t 'RN-LABELS' 'FAIL' 'Batch Rename did not open' }
        else {
            Start-Sleep -Milliseconds 1500
            $r = Labels $rn ("renamer_{0}" -f $t)
            $v = if ($Theme -eq 1) { V ($r.N -ge 8 -and $r.Min -ge 4.5) } else { 'INFO' }
            Row $t 'RN-LABELS' $v ("{0} checkboxes, lowest label contrast {1:0.00}" -f $r.N, $r.Min)
            [void][Drv098f]::PostMessageW($rn, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 1200
        }
        # File Comparator (Ctrl+Shift+C) on the two files: the Compare Files dialog, then its window
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        $fc = Open-ByKey $id 0x43
        if ($fc -ne [IntPtr]::Zero -and [Drv098f]::Cls($fc) -eq '#32770') { $known = Get-Tops $id; Click-Ok $fc; $fc = Wait-NewWin $id $known 20 }
        if ($fc -eq [IntPtr]::Zero) { Row $t 'FC-TOOLBAR' 'FAIL' 'File Comparator did not open'; return }
        Start-Sleep -Milliseconds 3000
        [void][Drv098f]::Send($fc, 0, 0, 0, 10000)
        $tb = @(Get-Desc $fc 'ToolbarWindow32') | Select-Object -First 1
        if ($tb) {
            $r = Toolbar-Dark $fc $tb ("fc_toolbar_{0}" -f $t)
            $script:Num["FC-TOOLBAR $t"] = $r.N
            Row $t 'FC-TOOLBAR' 'INFO' ("strip #{0:X6}; glyph pixels darker than the strip: {1}" -f $r.Bg, $r.N)
        }
        else { Row $t 'FC-TOOLBAR' 'FAIL' 'no toolbar' }
        $cap = [Cap416]::Capture($fc, $true); Save-Png $cap (Join-Path $CapDir ("fc_window_{0}.png" -f $t))
        $grey = [Px427]::Grey($cap, 0, 0, $cap.Width, $cap.Height)
        # minus the text of the two views (their client areas; their scrollbars are chrome and count)
        $o = New-Object Cap416+POINT; $o.x = 0; $o.y = 0; [void][Cap416]::ClientToScreen($fc, [ref]$o)
        $views = @(Get-Desc $fc 'SFC File View Window Class')
        $sized = @($views | ForEach-Object {
                $cr = New-Object Cap416+RECT; [void][Cap416]::GetClientRect($_, [ref]$cr)
                $p = New-Object Cap416+POINT; $p.x = 0; $p.y = 0; [void][Cap416]::ClientToScreen($_, [ref]$p)
                [pscustomobject]@{ H = $_; X0 = $p.x - $o.x; Y0 = $p.y - $o.y; X1 = $p.x - $o.x + $cr.right; Y1 = $p.y - $o.y + $cr.bottom } })
        $inViews = 0
        foreach ($s in $sized) { $inViews += [Px427]::Grey($cap, $s.X0, $s.Y0, $s.X1, $s.Y1) }
        $cap.Dispose()
        $script:Num["FC-GREY $t"] = $grey - $inViews
        Row $t 'FC-GREY' 'INFO' ("light-grey pixels outside the text views: {0} (in the views {1}; views: {2})" -f ($grey - $inViews), $inViews, (($sized | ForEach-Object { [Cap416]::Cls($_.H) }) -join ', '))
    }
    finally { Stop-Tc $id }
}

$backup = Join-Path $env:TEMP 'tc427_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
$script:Num = @{}
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Left
    Copy-Item -LiteralPath $Image -Destination (Join-Path $Left 'image.png')
    Copy-Item -LiteralPath $Image -Destination (Join-Path $Left 'image2.png')
    Set-Config
    & reg.exe add $CfgKey /v 'Toolbar Icon Set' /t REG_DWORD /d 0 /f | Out-Null
    Out ("dark427_probe {0} on {1}; hot keys: {2}; OS {3}" -f $Label, $Exe, (Set-HotKeys), [Environment]::OSVersion.Version)
    Run-Theme 1
    Run-Theme 0
    # compare with the before run
    $before = Join-Path $ProbeDir 'result_before_rows.txt'
    if ($Label -ne 'before' -and (Test-Path $before)) {
        $old = @{}
        foreach ($l in (Get-Content $before)) { if ($l -match '^NUM (\S+ \S+) (-?\d+)$') { $old[$Matches[1]] = [int]$Matches[2] } }
        foreach ($k in @('PV-TOOLBAR DARK', 'FC-TOOLBAR DARK')) {
            if ($old.ContainsKey($k) -and $script:Num.ContainsKey($k)) { Row 'DARK' ($k -replace ' DARK') (V ($script:Num[$k] -le [Math]::Floor($old[$k] * 0.1))) ("{0} -> {1} glyph pixels darker than the strip (needs <= 10 %)" -f $old[$k], $script:Num[$k]) }
        }
        if ($old.ContainsKey('FC-GREY DARK') -and $script:Num.ContainsKey('FC-GREY DARK')) { Row 'DARK' 'FC-GREY' (V ($script:Num['FC-GREY DARK'] -le [Math]::Floor($old['FC-GREY DARK'] * 0.01))) ("{0} -> {1} light-grey pixels (needs <= 1 %)" -f $old['FC-GREY DARK'], $script:Num['FC-GREY DARK']) }
        foreach ($n in @('pv_toolbar_DEFAULT.png', 'fc_toolbar_DEFAULT.png')) { $d = Same-As-Before $n; Row 'DEFAULT' 'DEFAULT-SAME' (V ($d -eq 0)) ("{0}: {1} pixels differ from the before run" -f $n, $d) }
        $d = Same-As-Before 'fc_window_DEFAULT.png'; Row 'DEFAULT' 'DEFAULT-SAME' 'INFO' ("fc_window_DEFAULT.png: {0} pixels differ (the views' scroll positions may vary)" -f $d)
    }
}
catch { Row 'PROBE' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    Out ("registry restored+identical: {0}" -f $restored)
    foreach ($k in $script:Num.Keys) { Out ("NUM {0} {1}" -f $k, $script:Num[$k]) }
    $fails = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("ROWS: {0} FAIL" -f $fails)
    [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding))
}
