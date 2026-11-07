<#
.SYNOPSIS
    Feature 408 feasibility probe (run on HEAD before any change): can a posted mouse click
    activate a link inside the Markdown Viewer's WebView2 page on the hidden desktop, and does
    a same-document fragment jump to a position:fixed element styled with :target scroll the
    page?

.DESCRIPTION
    Fixture %TEMP%\tc408f\files\a_doc.md, raw HTML only (inline style is allowed by mdview's
    content policy):
      - a fixed red box #t1 (hidden, shown by :target) at the bottom right of the viewport;
      - a blue block link to "#t1" at the top of the page;
      - a green block link to "foo.txt" (a local non-Markdown target: the viewer answers a
        user-initiated activation with a message box, 085 F3);
      - 200 lines of text so that the page can scroll.
    Rows:
      KIDS     the descendant windows of the viewer (classes) - where the clicks go
      CLICK-T  click on the blue link: PASS = red pixels appear (the fragment jump happened)
      NOSCROLL PASS = the blue block's top row is where it was before the click
      CLICK-L  click on the green link: PASS = a message box opens (the click counts as a user
               activation, so the host's OnActivateLink route can be driven)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Fs408' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Fs408
{
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    // red pixel count; first client row holding blue; first client row holding green
    public static string Measure(IntPtr wnd, string saveAs)
    {
        RECT wr; GetWindowRect(wnd, out wr);
        RECT cr; GetClientRect(wnd, out cr);
        POINT o = new POINT(); ClientToScreen(wnd, ref o);
        int w = wr.Right - wr.Left, h = wr.Bottom - wr.Top;
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(wnd, dc, 2); g.ReleaseHdc(dc); }
            if (saveAs != null) { try { bmp.Save(saveAs, ImageFormat.Png); } catch { } }
            int ox = o.X - wr.Left, oy = o.Y - wr.Top, cw = cr.Right, ch = cr.Bottom;
            int red = 0, blueTop = -1, greenTop = -1;
            for (int y = oy; y < oy + ch; y++)
                for (int x = ox; x < ox + cw; x += 2)
                {
                    Color c = bmp.GetPixel(x, y);
                    if (c.R > 220 && c.G < 80 && c.B < 80) red++;
                    if (blueTop < 0 && c.B > 220 && c.R < 40 && c.G < 40) blueTop = y - oy;
                    if (greenTop < 0 && c.G > 200 && c.R < 170 && c.B < 110) greenTop = y - oy;
                }
            return red + ";" + blueTop + ";" + greenTop + ";client=" + cw + "x" + ch;
        }
    }
}
'@
}

$Root = $TempRoot + '\tc408f'
$Files = $Root + '\files'
function Put-Text([string]$Path, [string]$Text) {
    if (-not $Path.StartsWith($Root + '\')) { throw "outside the fixture: $Path" }
    [IO.File]::WriteAllBytes($LP + $Path, $Utf8.GetBytes($Text))
}
function Shot([IntPtr]$W, [string]$Tag) {
    $png = $null; if ($OutFile) { $png = [IO.Path]::Combine([IO.Path]::GetDirectoryName($OutFile), ('shot_{0}_{1}.png' -f $Label, $Tag)) }
    return [Fs408]::Measure($W, $png)
}
function Part([string]$m, [int]$i) { return [int]($m.Split(';')[$i]) }
function Render-Kid([IntPtr]$W) {
    foreach ($k in [Drv098f]::Kids($W)) { if ([Drv098f]::Cls($k) -eq 'Chrome_RenderWidgetHostHWND') { return $k } }
    return [IntPtr]::Zero
}

$backup = Join-Path $env:TEMP 'tc408f_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $Files
    Set-Config
    $filler = (1..200 | ForEach-Object { "Line $_ of filler text." }) -join "`n`n"
    $doc = "<style>.t{position:fixed;right:10px;bottom:10px;width:160px;height:60px;background:#ff0000;visibility:hidden}.t:target{visibility:visible}</style>`n" +
    "<div id=`"t1`" class=`"t`"></div>`n`n" +
    "<a href=`"#t1`" style=`"display:block;width:300px;height:120px;background:#0000ff`"></a>`n`n" +
    "<a href=`"foo.txt`" style=`"display:block;width:300px;height:120px;background:#00ff00`"></a>`n`n" + $filler + "`n"
    Put-Text "$Files\a_doc.md" $doc
    Out ("feas408_probe (feature 408) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; desktop {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [DeskLib098]::Name())
    Out ''
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x28
        Start-Sleep -Milliseconds 400
        $w = Open-ByCmd $id 742 20
        if ($w -eq [IntPtr]::Zero -or [Drv098f]::Txt($w) -notlike '*Markdown Viewer*') { Row 'OPEN' 'RUN' 'NOT DRIVEN' ('no viewer: ' + $(if ($w -ne [IntPtr]::Zero) { WinDesc $w } else { '-' })) }
        else {
            [void][Fs408]::SetWindowPos($w, [IntPtr]::Zero, 0, 0, 1200, 900, 0x0014)
            Start-Sleep -Milliseconds 5000
            $scale = [Fs408]::GetDpiForWindow($w) / 96.0
            $kids = @([Drv098f]::Kids($w) | ForEach-Object { [Drv098f]::Cls($_) })
            Row 'KIDS' 'RUN' 'INFO' (($kids -join ', ') + "; scale $scale")
            $rk = Render-Kid $w
            $m0 = Shot $w 'start'
            Out ("start: red;blueTop;greenTop = {0}" -f $m0)
            if ($rk -eq [IntPtr]::Zero -or (Part $m0 1) -lt 0) { Row 'CLICK-T' 'RUN' 'NOT DRIVEN' ("render widget {0}; measure {1}" -f $rk, $m0) }
            else {
                # the render widget's client origin vs the viewer's client origin
                $p = New-Object Fs408+POINT; [void][Fs408]::ClientToScreen($rk, [ref]$p)
                $q = New-Object Fs408+POINT; [void][Fs408]::ClientToScreen($w, [ref]$q)
                $dx = $p.X - $q.X; $dy = $p.Y - $q.Y
                $bx = [int](250 * $scale) ; $by = (Part $m0 1) + [int](40 * $scale) - $dy
                Post-Click $rk $bx $by
                Start-Sleep -Milliseconds 2000
                $m1 = Shot $w 'afterT'
                Row 'CLICK-T' 'RUN' (V ((Part $m1 0) -gt 100)) ("click at {0},{1} (widget offset {2},{3}); after {4}" -f $bx, $by, $dx, $dy, $m1)
                Row 'NOSCROLL' 'RUN' (V ((Part $m1 1) -eq (Part $m0 1))) ("blue top before {0}, after {1}" -f (Part $m0 1), (Part $m1 1))
                $known = Get-Tops $id
                $gy = (Part $m1 2) + [int](40 * $scale) - $dy
                Post-Click $rk $bx $gy
                $mb = Wait-NewWin $id $known 6
                if ($mb -ne [IntPtr]::Zero) { Row 'CLICK-L' 'RUN' 'PASS' ('message box: ' + (WinDesc $mb)); Click-Ok $mb }
                else { Row 'CLICK-L' 'RUN' 'FAIL' ("no window after the click at {0},{1}" -f $bx, $gy) }
            }
            [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 1500
        }
    }
    catch { Row 'RUN' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'RUN' $id $null $before } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
