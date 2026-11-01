<#
.SYNOPSIS
    Feature 376 probe: opening a folder found by quick search never draws the whole parent folder
    in between.

.DESCRIPTION
    Each round starts a fresh instance with the left panel on a fixture folder that holds five
    folders (aaa_one, big, ccc_three, ddd_four, eee_five; with ".." six rows); 'big' holds
    -BigCount files, so that reading it keeps the program busy long enough to be seen. The panel
    is switched to the Detailed view, then:
      REF   type 'big', Esc: the panel shows the whole parent folder with the cursor on 'big'
            (the picture a flash would show) - captured as the reference FULL;
            type 'big' again: the filtered view - captured as the reference FILT
      ENTER post Enter to the list box and sample its pixels (BitBlt from the window DC, from
            another thread of this process, while the program is busy) for -SampleMs ms; every
            sample is classified:
              FILT    the area below the last parent row is the search tint (the filtered view)
              PARENT  that area is the plain background and the last parent row ('eee_five')
                      is drawn as in FULL - the whole parent folder (the flash)
              NEW     that area holds text (the 'big' listing, -BigCount rows)
              OTHER   anything else (a sample taken in the middle of a paint)
      CTRL  the classifier sees FULL as PARENT and FILT as FILT, and the last sample is NEW
            (else the measurement is invalid)
      FLASH PASS when no sample was PARENT
      LOC   the panel is in 'big' afterwards (Change Directory field)
      BACK  Backspace from 'big' returns to the parent with the cursor on 'big' (Enter on the
            cursor opens 'big' again)
    After the rounds, two failure cases (the panel stays in the parent folder):
      DENY  'ddd_four' cannot be listed (a deny ACE for the user, removed in finally): after Enter
            and the error message the panel shows the whole parent folder (class PARENT), no tint
      GONE  'fff_gone' is deleted just before Enter: after the error the panel shows a drawn,
            untinted listing of the parent
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib,
    [int]$Rounds = 3,
    [int]$BigCount = 30000,
    [int]$SampleMs = 4000
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
Add-Type -AssemblyName System.Drawing
if (-not ('Smp376' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Smp376
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr d, int x, int y, int w, int h, IntPtr s, int sx, int sy, uint rop);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);

    public static int W, H;
    public static int[] Grab(IntPtr h)
    {
        RECT r; GetClientRect(h, out r);
        int w = r.Right - r.Left, hh = r.Bottom - r.Top;
        if (w <= 0 || hh <= 0) return null;
        W = w; H = hh;
        using (var bmp = new Bitmap(w, hh, PixelFormat.Format32bppRgb))
        {
            using (var g = Graphics.FromImage(bmp))
            {
                IntPtr d = g.GetHdc();
                IntPtr s = GetDC(h);
                BitBlt(d, 0, 0, w, hh, s, 0, 0, 0x00CC0020);
                ReleaseDC(h, s);
                g.ReleaseHdc(d);
            }
            var data = bmp.LockBits(new Rectangle(0, 0, w, hh), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
            var px = new int[w * hh];
            for (int y = 0; y < hh; y++)
                Marshal.Copy(data.Scan0 + y * data.Stride, px, y * w, w);
            bmp.UnlockBits(data);
            for (int i = 0; i < px.Length; i++) px[i] &= 0xFFFFFF;
            return px;
        }
    }
    public static void Save(int[] px, int w, int h, string file)
    {
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppRgb))
        {
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppRgb);
            for (int y = 0; y < h; y++) Marshal.Copy(px, y * w, data.Scan0 + y * data.Stride, w);
            bmp.UnlockBits(data);
            bmp.Save(file, ImageFormat.Png);
        }
    }

    // the classifier, built from the two references
    public static int Bg, Tint, XMax, YEnd, BTop, BBottom, RefW, RefH;
    static List<int> aIdx = new List<int>();
    static List<int> aVal = new List<int>();
    static int Most(int[] px, int w, int x0, int x1, int y0, int y1)
    {
        var c = new Dictionary<int, int>();
        for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) { int v = px[y * w + x]; int n; c.TryGetValue(v, out n); c[v] = n + 1; }
        int best = 0, bn = -1;
        foreach (var kv in c) if (kv.Value > bn) { bn = kv.Value; best = kv.Key; }
        return best;
    }
    public static string Build(int[] full, int[] filt, int w, int h)
    {
        RefW = w; RefH = h;
        XMax = w - 40;
        int yLimit = h - 30;
        if (XMax < 100 || yLimit < 100) return "panel too small " + w + "x" + h;
        Bg = Most(full, w, 0, XMax, yLimit - 40, yLimit);
        Tint = Most(filt, w, 0, XMax, yLimit - 40, yLimit);
        if (Bg == Tint) return "no tint: background and filtered view have the same colour " + Bg.ToString("X6");
        YEnd = -1;
        for (int y = 0; y < yLimit; y++)
            for (int x = 40; x < XMax; x++)
                if (full[y * w + x] != Bg) { YEnd = y; break; }
        if (YEnd < 0) return "the reference FULL has no text";
        BTop = YEnd + 8; BBottom = Math.Min(yLimit, YEnd + 160);
        if (BBottom - BTop < 40) return "too little room below the parent rows";
        aIdx.Clear(); aVal.Clear();
        for (int y = Math.Max(0, YEnd - 12); y <= YEnd; y++)
            for (int x = 40; x < XMax; x++)
                if (full[y * w + x] != Bg) { aIdx.Add(y * w + x); aVal.Add(full[y * w + x]); }
        if (aIdx.Count < 10) return "the last parent row has too few text pixels";
        return null;
    }
    public static string Classify(int[] px, int w, int h)
    {
        if (px == null) return "NONE";
        if (w != RefW || h != RefH) return "SIZE";
        long n = 0, nb = 0, nt = 0;
        for (int y = BTop; y < BBottom; y++)
            for (int x = 0; x < XMax; x++) { int v = px[y * w + x]; n++; if (v == Bg) nb++; else if (v == Tint) nt++; }
        if (nt * 10 >= n * 9) return "FILT";
        if (nb == n)
        {
            int m = 0;
            for (int i = 0; i < aIdx.Count; i++) if (px[aIdx[i]] == aVal[i]) m++;
            if (m * 10 >= aIdx.Count * 9) return "PARENT";
            return "OTHER";
        }
        if (nb * 10 >= n * 7 && nt * 20 < n) return "NEW";
        return "OTHER";
    }

    // pixels of the search tint / of anything but the background in the panel (scroll bar and bottom
    // bar excluded), with the colours of the classifier
    public static int TintCount(int[] px, int w, int h)
    {
        int n = 0;
        for (int y = 0; y < h - 30; y++) for (int x = 0; x < Math.Min(XMax, w); x++) if (px[y * w + x] == Tint) n++;
        return n;
    }
    public static int InkCount(int[] px, int w, int h)
    {
        int n = 0;
        for (int y = 0; y < h - 30; y++) for (int x = 40; x < Math.Min(XMax, w); x++) { int v = px[y * w + x]; if (v != Bg && v != Tint) n++; }
        return n;
    }

    // posts Enter to the list box and samples it for 'ms' milliseconds; the runs as "STATE xN @t0-t1ms"
    public static List<string> Runs = new List<string>();
    public static string Last;
    public static int ParentCount, Samples;
    public static int[] FirstParent;
    public static void EnterAndSample(IntPtr list, int ms)
    {
        Runs.Clear(); ParentCount = 0; Samples = 0; FirstParent = null; Last = null;
        var sw = Stopwatch.StartNew();
        PostMessageW(list, 0x0100, (IntPtr)0x0D, (IntPtr)1);
        PostMessageW(list, 0x0101, (IntPtr)0x0D, unchecked((IntPtr)(int)0xC0000001));
        string cur = null; int cnt = 0; long t0 = 0, t1 = 0;
        while (sw.ElapsedMilliseconds < ms)
        {
            long t = sw.ElapsedMilliseconds;
            var px = Grab(list);
            string s = Classify(px, W, H);
            Samples++;
            if (s == "PARENT") { ParentCount++; if (FirstParent == null) FirstParent = px; }
            if (s != cur)
            {
                if (cur != null) Runs.Add(cur + " x" + cnt + " @" + t0 + "-" + t1 + "ms");
                cur = s; cnt = 0; t0 = t;
            }
            cnt++; t1 = t;
            Last = s;
        }
        if (cur != null) Runs.Add(cur + " x" + cnt + " @" + t0 + "-" + t1 + "ms");
    }
}
'@
}

$Root = $TempRoot + '\tc376'
$RegBackup = $TempRoot + '\tc376_backup.reg'
function Assert-In([string]$p) { if (-not ($p + '\').StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "path outside the fixture: $p" } }
$Left = $Root + '\left'; $Big = $Left + '\big'; $OutD = $Root + '\out'

function Make-Fixture {
    Assert-In $Left; Assert-In $OutD
    foreach ($d in @('aaa_one', 'big', 'ccc_three', 'ddd_four', 'eee_five')) { NewDir ($Left + '\' + $d) }
    $have = @([IO.Directory]::EnumerateFiles($Big)).Count
    if ($have -ne $BigCount) {
        Get-ChildItem -LiteralPath $Big -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
        $empty = [byte[]]@()
        for ($i = 1; $i -le $BigCount; $i++) { [IO.File]::WriteAllBytes(('{0}\file_{1:D6}.txt' -f $Big, $i), $empty) }
    }
    if (Test-Path -LiteralPath $OutD) { Get-ChildItem -LiteralPath $OutD -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force } }
    NewDir $OutD
}
function Start-Tc376 {
    $a = @('-t', 'T376', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $OutD), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Type-Text([int]$Id, [string]$Text) {
    $l = Get-LeftList $Id
    foreach ($c in $Text.ToCharArray()) { [void][Drv098f]::Send($l, 0x0102, [int]$c, 1, 30000) }
    Start-Sleep -Milliseconds 400
}
function Settle([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 30000); Start-Sleep -Milliseconds 1200 }

$existed = Backup-Reg $RegBackup
Out ("Feature 376 probe {0}; exe {1}; rounds {2}; files in 'big' {3}; registry backup {4} (existed {5})" -f $Label, $Exe, $Rounds, $BigCount, $RegBackup, $existed)
if ($existed) { Out ('export SHA-256 ' + (Get-FileHash -LiteralPath $RegBackup).Hash) }
try {
    Set-Config
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Quick Search Enter Alt' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Quick Search Filter' /t REG_DWORD /d 1 /f | Out-Null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Make-Fixture
    Out ("fixture {0} ready in {1:N1} s" -f $Root, $sw.Elapsed.TotalSeconds)
    for ($r = 1; $r -le $Rounds; $r++) {
        $case = 'R' + $r
        $before = Reports; $id = 0
        try {
            Make-Fixture
            $id = Start-Tc376
            Post-Cmd (Get-Main $id) 2982; Settle $id          # Detailed view
            $list = Get-LeftList $id
            Type-Text $id 'big'; Key $id 0x1B; Settle $id
            $full = [Smp376]::Grab($list); $w = [Smp376]::W; $h = [Smp376]::H
            Type-Text $id 'big'; Settle $id
            $filt = [Smp376]::Grab($list)
            if ($r -eq 1 -and $OutFile) {
                $base = [IO.Path]::ChangeExtension($OutFile, $null).TrimEnd('.')
                [Smp376]::Save($full, $w, $h, $base + '_ref_full.png'); [Smp376]::Save($filt, $w, $h, $base + '_ref_filt.png')
            }
            $err = [Smp376]::Build($full, $filt, $w, $h)
            if ($err) { Row $case 'CTRL' 'FAIL' ("classifier not built: {0}" -f $err); continue }
            $cf = [Smp376]::Classify($full, $w, $h); $ct = [Smp376]::Classify($filt, $w, $h)
            [Smp376]::EnterAndSample($list, $SampleMs)
            Settle $id
            $lastNow = [Smp376]::Classify([Smp376]::Grab($list), $w, $h)
            $ctrlOk = ($cf -eq 'PARENT') -and ($ct -eq 'FILT') -and ($lastNow -eq 'NEW')
            Row $case 'CTRL' (V $ctrlOk) ("panel {0}x{1}; bg {2:X6} tint {3:X6}; rows end y={4}; area below y={5}..{6}; FULL->{7} FILT->{8} settled->{9}" -f $w, $h, [Smp376]::Bg, [Smp376]::Tint, [Smp376]::YEnd, [Smp376]::BTop, [Smp376]::BBottom, $cf, $ct, $lastNow)
            Row $case 'FLASH' (V ([Smp376]::ParentCount -eq 0)) ("samples {0}; PARENT {1}; runs: {2}" -f [Smp376]::Samples, [Smp376]::ParentCount, (([Smp376]::Runs) -join ', '))
            if ([Smp376]::FirstParent -ne $null -and $r -eq 1 -and $OutFile) {
                $base = [IO.Path]::ChangeExtension($OutFile, $null).TrimEnd('.')
                [Smp376]::Save([Smp376]::FirstParent, $w, $h, $base + '_flash.png')
            }
            $loc = Get-Loc $id
            Row $case 'LOC' (V ($loc -ieq $Big)) ("panel at {0}" -f (Esc $loc))
            Key $id 0x08; Settle $id                            # Backspace: up to the parent
            $up = Get-Loc $id
            Key $id 0x0D; Settle $id                            # Enter on the item under the cursor
            $again = Get-Loc $id
            Row $case 'BACK' (V (($up -ieq $Left) -and ($again -ieq $Big))) ("after Backspace at {0}; Enter on the cursor opened {1}" -f (Esc $up), (Esc $again))
        }
        catch { Row $case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { $fatal = Fatal-Win $id; End-Row $case $id $fatal $before } }
    }

    # DENY: the folder found cannot be listed (access denied) - the panel stays in the parent and
    # must show its whole listing, drawn and untinted (classifier PARENT: the picture of Esc)
    if ([Smp376]::Bg -ne [Smp376]::Tint) {
        $case = 'DENY'; $before = Reports; $id = 0
        $denied = $Left + '\ddd_four'; Assert-In $denied
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        try {
            Make-Fixture
            & icacls.exe $denied /deny ('*' + $sid + ':(RD)') | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'icacls /deny failed' }
            $id = Start-Tc376
            Post-Cmd (Get-Main $id) 2982; Settle $id
            $list = Get-LeftList $id
            Type-Text $id 'ddd'; Settle $id
            $filtNow = [Smp376]::Classify([Smp376]::Grab($list), [Smp376]::W, [Smp376]::H)
            [void][Drv098f]::PostMessageW($list, 0x0100, [IntPtr]0x0D, [IntPtr]1)
            [void][Drv098f]::PostMessageW($list, 0x0101, [IntPtr]0x0D, [IntPtr](-1073741823))
            Start-Sleep -Milliseconds 500
            $sv = Serve $id 20 @(1, 6)
            Settle $id
            $px = [Smp376]::Grab($list); $w = [Smp376]::W; $h = [Smp376]::H
            $cls = [Smp376]::Classify($px, $w, $h); $tint = [Smp376]::TintCount($px, $w, $h)
            $loc = Get-Loc $id
            Row $case 'DRAWN' (V (($filtNow -eq 'FILT') -and ($cls -eq 'PARENT') -and ($tint -eq 0) -and ($loc -ieq $Left))) ("before Enter {0}; after {1}; tint pixels {2}; panel at {3}; {4}" -f $filtNow, $cls, $tint, (Esc $loc), (Msgs $sv))
        }
        catch { Row $case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally {
            if ($id) { $fatal = Fatal-Win $id; End-Row $case $id $fatal $before }
            & icacls.exe $denied /remove:d ('*' + $sid) | Out-Null
        }

        # GONE: the folder found is deleted just before Enter - the change fails, the panel stays in
        # the parent and must show its listing, drawn and untinted
        $case = 'GONE'; $before = Reports; $id = 0
        $gone = $Left + '\fff_gone'; Assert-In $gone
        try {
            Make-Fixture
            NewDir $gone
            $id = Start-Tc376
            Post-Cmd (Get-Main $id) 2982; Settle $id
            $list = Get-LeftList $id
            Type-Text $id 'fff'; Settle $id
            $px0 = [Smp376]::Grab($list); $tint0 = [Smp376]::TintCount($px0, [Smp376]::W, [Smp376]::H)
            [IO.Directory]::Delete($gone)
            [void][Drv098f]::PostMessageW($list, 0x0100, [IntPtr]0x0D, [IntPtr]1)
            [void][Drv098f]::PostMessageW($list, 0x0101, [IntPtr]0x0D, [IntPtr](-1073741823))
            Start-Sleep -Milliseconds 500
            $sv = Serve $id 20 @(1, 6)
            Settle $id
            $px = [Smp376]::Grab($list); $w = [Smp376]::W; $h = [Smp376]::H
            $tint = [Smp376]::TintCount($px, $w, $h); $ink = [Smp376]::InkCount($px, $w, $h)
            $ref = [Smp376]::Classify($px, $w, $h)
            $loc = Get-Loc $id
            Row $case 'DRAWN' (V (($tint0 -gt 0) -and ($tint -eq 0) -and ($ink -gt 0) -and ($loc -ieq $Left))) ("tint pixels before Enter {0}, after {1}; ink {2}; class {3}; panel at {4}; {5}" -f $tint0, $tint, $ink, $ref, (Esc $loc), (Msgs $sv))
        }
        catch { Row $case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally {
            if ($id) { $fatal = Fatal-Win $id; End-Row $case $id $fatal $before }
            if (Test-Path -LiteralPath $gone) { [IO.Directory]::Delete($gone) }
        }
    }
    else { Row 'DENY' 'SKIP' 'FAIL' 'no classifier (the rounds did not build one)' }
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
