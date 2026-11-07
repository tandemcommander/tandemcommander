<#
.SYNOPSIS
    Feature 409 probe: Compare Directories (command 737) in a language - does the mask-hints link
    (control 102, IDC_FILEMASK_HINT) show its whole text?

.DESCRIPTION
    Starts the program in -Lang with two empty fixture folders as the panels, opens Compare
    Directories expanded (Configuration\Compare More Options = 1), then:
      FIT  the link's text (WM_GETTEXT) measured in "MS Shell Dlg" 8 pt at the window's DPI is not
           wider than the link's client area (the control draws right-aligned at Width - TextWidth:
           wider text loses its first letters);
      SHOT a PrintWindow picture of the dialog into -Png (works on a hidden desktop).
    Cancels the dialog and ends the program. MUST run through tools\run_on_hidden_desktop.ps1;
    refuses when tandemcommander.exe already runs. Registry exported, restored, verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string]$Lang = 'czech',
    [Parameter(Mandatory = $true)][string]$Png
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\124-regedt-key-text\probe\shotocr_lib.ps1')
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Fit409
{
    [StructLayout(LayoutKind.Sequential)] public struct SIZE { public int cx, cy; }
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr CreateFontW(int h, int w, int e, int o, int wt, uint i, uint u, uint s, uint cs, uint op, uint cp, uint q, uint pf, string face);
    [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
    [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern bool GetTextExtentPoint32W(IntPtr dc, string s, int n, out SIZE sz);
    [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr r, IntPtr rgn, uint flags);
    // the window painted in full, children too (RDW_INVALIDATE|ERASE|ALLCHILDREN|UPDATENOW|FRAME):
    // a PrintWindow right after the dialog opened sometimes caught children not painted yet
    public static bool Repaint(IntPtr h) { return RedrawWindow(h, IntPtr.Zero, IntPtr.Zero, 0x0001 | 0x0004 | 0x0080 | 0x0100 | 0x0400); }
    // dark pixels (sum of RGB < 384) inside a rectangle of a saved picture: the link's text is drawn
    public static int Ink(string png, int x, int y, int w, int h)
    {
        int n = 0;
        using (var bmp = new System.Drawing.Bitmap(png))
            for (int j = Math.Max(0, y); j < Math.Min(bmp.Height, y + h); j++)
                for (int i = Math.Max(0, x); i < Math.Min(bmp.Width, x + w); i++)
                {
                    var c = bmp.GetPixel(i, j);
                    if (c.R + c.G + c.B < 384) n++;
                }
        return n;
    }
    public static int Width(string text, uint dpi)
    {
        IntPtr dc = CreateCompatibleDC(IntPtr.Zero);
        IntPtr f = CreateFontW(-(int)Math.Round(8.0 * dpi / 72.0), 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0, "MS Shell Dlg");
        IntPtr old = SelectObject(dc, f);
        SIZE sz; GetTextExtentPoint32W(dc, text, text.Length, out sz);
        SelectObject(dc, old); DeleteObject(f); DeleteDC(dc);
        return sz.cx;
    }
}
'@
$Root = $TempRoot + '\tc409'
$StartDir = $Root + '\right'
$LeftDir = $Root + '\left'
$backup = Join-Path $env:TEMP 'tc409_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
try {
    NewDir $StartDir
    NewDir $LeftDir
    Set-Config
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d ($Lang + '.slg') /f | Out-Null
    # the link sits in the part the More button shows; open the dialog expanded
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Compare More Options' /t REG_DWORD /d 1 /f | Out-Null
    $id = Start-Tc $LeftDir
    $dlg = Open-ByCmd $id 737 15
    if ($dlg -eq [IntPtr]::Zero) { Row 'CMP' 'OPEN' 'NOT DRIVEN' 'Compare Directories opened no window' }
    else {
        Start-Sleep -Milliseconds 1500
        $title = [Drv098f]::Txt($dlg)
        $hint = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 102 -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        if (-not $hint) { Row 'CMP' 'FIT' 'FAIL' ("'{0}': no visible control 102" -f (Esc $title)) }
        else {
            $text = ([Drv098f]::Txt($hint)) -replace '&(.)', '$1'
            $r = New-Object Drv098f+RECT
            [void][Drv098f]::GetClientRect($hint, [ref]$r)
            $cw = $r.Right - $r.Left
            $dpi = [Fit409]::GetDpiForWindow($hint)
            $tw = [Fit409]::Width($text, $dpi)
            Row 'CMP' 'FIT' (V ($tw -gt 0 -and $tw -le $cw)) ("{0} '{1}': link '{2}' needs {3} px, has {4} px (dpi {5})" -f $Lang, (Esc $title), (Esc $text), $tw, $cw, $dpi)
        }
        [void][Fit409]::Repaint($dlg)
        Start-Sleep -Milliseconds 1500
        $ok = [Shot124]::Capture($dlg, $Png)
        Row 'CMP' 'SHOT' $(if ($ok) { 'PASS' } else { 'FAIL' }) ("{0}: captured {1} -> {2}" -f $Lang, $ok, $Png)
        if ($hint -and $ok) {
            # the link's whole text in the picture: ink in the left part of the text's rectangle
            # (right-aligned: the text spans the last $tw px of the control; its first letters are the
            # ones a too-narrow control cuts) and in the right part
            $rr = [Shot124]::RelRect($dlg, $hint)
            $left = [Fit409]::Ink($Png, $rr[0] + $rr[2] - $tw, $rr[1], [Math]::Min(12, $tw), $rr[3])
            $right = [Fit409]::Ink($Png, $rr[0] + $rr[2] - 12, $rr[1], 12, $rr[3])
            Row 'CMP' 'INK' (V ($left -gt 0 -and $right -gt 0)) ("{0}: dark pixels in the first 12 px of the text {1}, in the last 12 px {2} (link at {3},{4} {5}x{6} in the picture)" -f $Lang, $left, $right, $rr[0], $rr[1], $rr[2], $rr[3])
        }
        Close-Win $dlg
    }
    End-Row 'CMP' $id $null (Reports)
}
catch { Row 'CMP' 'ERROR' 'FAIL' ($_.Exception.Message) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    Out ("Registry restored+identical: {0}" -f $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
