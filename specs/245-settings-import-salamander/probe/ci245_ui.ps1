<#
.SYNOPSIS
    Feature 245 UI probe (quickstart V3): drives the import wizard through its pages by control
    ids (no keyboard), checks the enabling rules, Back/Cancel on each page, a complete import, the
    first-start offer (once, never again) and captures every page (light and dark theme).

.DESCRIPTION
    U1  wizard from the menu: five pages, Back works, preview + result texts, registry changed
    U2  Cancel on every page changes nothing
    U3  dark theme: pages captured
    U4  first start of a fresh configuration: the offer appears once; Not now; never again
    U5  the offer answered Import now opens the wizard
    Works with -Exe (Debug or Release). Debug: the fixtures reach the program through
    TC_CFGIMPORT_TEST_ROOT. Release has no test root: -Release skips the steps that need
    fixtures and only checks that the command opens the wizard and Cancel changes nothing.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored, verified.
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$OutFile,
    [switch]$Release
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ci245_lib.ps1')
. (Join-Path $PSScriptRoot 'ci245_fixtures.ps1')
Add-Type -AssemblyName System.Drawing
if (-not ('Ui245' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Text;
using System.Drawing;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Ui245
{
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, StringBuilder l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Text(IntPtr h)
    {
        IntPtr r; int n = 0;
        if (SendMessageTimeoutW(h, 0x000E, IntPtr.Zero, IntPtr.Zero, 2, 3000, out r) != IntPtr.Zero) n = (int)r;
        var s = new StringBuilder(n + 2);
        SendMessageW(h, 0x000D, (IntPtr)(n + 1), s);
        return s.ToString();
    }
    public static IntPtr[] Tops(uint pid)
    {
        var r = new List<IntPtr>();
        EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); if (p == pid && IsWindowVisible(h)) r.Add(h); return true; }, IntPtr.Zero);
        return r.ToArray();
    }
    public static IntPtr[] Kids(IntPtr p)
    {
        var r = new List<IntPtr>();
        EnumChildWindows(p, (h, l) => { r.Add(h); return true; }, IntPtr.Zero);
        return r.ToArray();
    }
    public static void Capture(IntPtr h, string file)
    {
        RECT r; GetWindowRect(h, out r);
        int w = r.Right - r.Left, hh = r.Bottom - r.Top;
        if (w <= 0 || hh <= 0) return;
        using (var bmp = new Bitmap(w, hh, System.Drawing.Imaging.PixelFormat.Format32bppRgb))
        {
            using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
            bmp.Save(file, System.Drawing.Imaging.ImageFormat.Png);
        }
    }
}
'@
}
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (-not $OutFile) { $OutFile = Join-Path $OutDir 'result_ui.txt' }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$backup = Join-Path $OutDir 'tc_backup.reg'
$existed = Backup-TC $backup
$before0 = Get-RegDump $script:TCPS

$WM_COMMAND = 0x0111; $BM_CLICK = 0x00F5; $BM_GETCHECK = 0x00F0; $LB_GETCOUNT = 0x018B; $LB_GETCURSEL = 0x0188; $LVM_GETITEMCOUNT = 0x1004; $WM_CLOSE = 0x0010
$IDOK = 1; $IDCANCEL = 2; $IDYES = 6; $IDNO = 7
$IDC_BACK = 6266; $IDC_SOURCES = 6264; $IDC_GROUPS = 6267; $IDE_TEXT = 6278; $IDC_CONSENT = 6279; $IDC_COPY = 6280; $IDC_PWD_IMPORT = 6274
$CM_IMPORT = 2948

function Start-TC([bool]$TestRoot = $true) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.UseShellExecute = $false
    if ($TestRoot) { $psi.EnvironmentVariables['TC_CFGIMPORT_TEST_ROOT'] = $script:FixRel }
    return [System.Diagnostics.Process]::Start($psi)
}
function Main-Of($p) {
    for ($i = 0; $i -lt 100; $i++) {
        foreach ($h in [Ui245]::Tops([uint32]$p.Id)) { if ([Ui245]::Cls($h) -like 'TandemCommanderMainWindow*') { return $h } }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}
# a visible dialog (#32770) of the process whose title matches, waiting up to $Seconds
function Wait-Dialog($p, [string]$TitleLike, [double]$Seconds = 15, $Exclude = $null) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        foreach ($h in [Ui245]::Tops([uint32]$p.Id)) {
            if ($Exclude -ne $null -and $h -eq $Exclude) { continue }
            if ([Ui245]::Cls($h) -eq '#32770' -and ([Ui245]::Text($h) -like $TitleLike)) { return $h }
        }
        Start-Sleep -Milliseconds 150
    }
    return [IntPtr]::Zero
}
function Gone([IntPtr]$h, [double]$Seconds = 10) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) { if (-not [Ui245]::IsWindowVisible($h)) { return $true }; Start-Sleep -Milliseconds 100 }
    return $false
}
function Click([IntPtr]$dlg, [int]$id) { [void][Ui245]::PostMessageW([Ui245]::GetDlgItem($dlg, $id), $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) }
function Item([IntPtr]$dlg, [int]$id) { return [Ui245]::GetDlgItem($dlg, $id) }
function Stop-TC($p) {
    if ($p.HasExited) { return }
    $m = Main-Of $p
    if ($m -ne [IntPtr]::Zero) { [void][Ui245]::PostMessageW($m, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
    if (-not $p.WaitForExit(30000)) { try { $p.Kill() } catch {}; $p.WaitForExit(5000) | Out-Null }
}
function Snap([IntPtr]$h, [string]$name) { try { [Ui245]::Capture($h, (Join-Path $OutDir $name)) } catch {} }

try {
    Remove-Fixtures
    # ---------------------------------------------------------------- U1 complete run
    New-TCConfig $Exe $OutDir | Out-Null
    if (-not $Release) {
        $blobs = Get-Blobs $Exe $OutDir 'pa55word' 'Master!23'
        New-AltapFixture -Blobs $blobs | Out-Null
    }
    $p = Start-TC
    $main = Main-Of $p
    Check 'U1 main window' ($main -ne [IntPtr]::Zero) ''
    [void][Ui245]::PostMessageW($main, $WM_COMMAND, [IntPtr]$CM_IMPORT, [IntPtr]::Zero)
    $d1 = Wait-Dialog $p 'Import Settings from Salamander'
    Check 'U1 page 1 opens from the menu command' ($d1 -ne [IntPtr]::Zero) ''
    if ($d1 -ne [IntPtr]::Zero -and -not $Release) {
        $lb = Item $d1 $IDC_SOURCES
        $cnt = [int][Ui245]::SendMessageW($lb, $LB_GETCOUNT, [IntPtr]::Zero, [IntPtr]::Zero)
        $sel = [int][Ui245]::SendMessageW($lb, $LB_GETCURSEL, [IntPtr]::Zero, [IntPtr]::Zero)
        Check 'U1 page 1 lists the fixture, newest selected' ($cnt -eq 1 -and $sel -eq 0) "count=$cnt sel=$sel"
        Check 'U1 page 1 Back disabled, Next enabled' (-not [Ui245]::IsWindowEnabled((Item $d1 $IDC_BACK)) -and [Ui245]::IsWindowEnabled((Item $d1 $IDOK))) ''
        Snap $d1 'u1_page1.png'
        Click $d1 $IDOK
        [void](Gone $d1)
        $d2 = Wait-Dialog $p 'Import Settings from Salamander'
        $lv = Item $d2 $IDC_GROUPS
        $rows = [int][Ui245]::SendMessageW($lv, $LVM_GETITEMCOUNT, [IntPtr]::Zero, [IntPtr]::Zero)
        Check 'U1 page 2 lists the groups' ($rows -ge 13) "rows=$rows"
        Snap $d2 'u1_page2.png'
        Click $d2 $IDC_BACK
        [void](Gone $d2)
        $d1b = Wait-Dialog $p 'Import Settings from Salamander'
        Check 'U1 Back from page 2 shows page 1' ($d1b -ne [IntPtr]::Zero -and (Item $d1b $IDC_SOURCES) -ne [IntPtr]::Zero) ''
        Click $d1b $IDOK
        [void](Gone $d1b)
        $d2 = Wait-Dialog $p 'Import Settings from Salamander'
        Click $d2 $IDOK
        [void](Gone $d2)
        $d3 = Wait-Dialog $p '*Saved Passwords*'
        Check 'U1 page 3 (saved passwords) shown for FTP with passwords' ($d3 -ne [IntPtr]::Zero) ''
        if ($d3 -ne [IntPtr]::Zero) {
            $chk = [int][Ui245]::SendMessageW((Item $d3 $IDC_PWD_IMPORT), $BM_GETCHECK, [IntPtr]::Zero, [IntPtr]::Zero)
            Check 'U1 page 3 import passwords preselected' ($chk -eq 1) ''
            Snap $d3 'u1_page3.png'
            Click $d3 $IDOK
            [void](Gone $d3)
        }
        $d4 = Wait-Dialog $p '*Preview*' 30
        Check 'U1 page 4 preview' ($d4 -ne [IntPtr]::Zero) ''
        if ($d4 -ne [IntPtr]::Zero) {
            $t = [Ui245]::Text((Item $d4 $IDE_TEXT))
            Check 'U1 preview text' ($t -match 'Preview of the import from Altap Salamander 4\.0' -and $t -match 'Hot paths \[Add\]' -and $t -match 'Bookmark Work') ($t.Substring(0, [Math]::Min(120, $t.Length)))
            Check 'U1 defaults: no consent box, Import enabled' (-not [Ui245]::IsWindowVisible((Item $d4 $IDC_CONSENT)) -and [Ui245]::IsWindowEnabled((Item $d4 $IDOK))) ''
            Snap $d4 'u1_page4.png'
            Click $d4 $IDOK
            [void](Gone $d4 30)
        }
        $d5 = Wait-Dialog $p '*Result*' 60
        Check 'U1 page 5 result' ($d5 -ne [IntPtr]::Zero) ''
        if ($d5 -ne [IntPtr]::Zero) {
            $t = [Ui245]::Text((Item $d5 $IDE_TEXT))
            Check 'U1 result text: finished, backup named' ($t -match 'finished' -and $t -match 'Backup of your previous settings' -and $t -notmatch 'not imported -') ($t.Substring(0, [Math]::Min(120, $t.Length)))
            Check 'U1 result has Copy and no Back' ((Item $d5 $IDC_COPY) -ne [IntPtr]::Zero -and (Item $d5 $IDC_BACK) -eq [IntPtr]::Zero) ''
            Snap $d5 'u1_page5.png'
            Click $d5 $IDOK
            [void](Gone $d5)
        }
    }
    elseif ($d1 -ne [IntPtr]::Zero) {
        Snap $d1 'u1_release_page1.png'
        Click $d1 $IDCANCEL
        [void](Gone $d1)
    }
    Stop-TC $p
    if (-not $Release) {
        $slots = @(Get-ChildItem "$script:TCRoot\Hot Paths" -ErrorAction SilentlyContinue | ForEach-Object { (Get-ItemProperty $_.PSPath).Path })
        Check 'U1 imported hot paths stored after exit' ($slots -contains 'C:\Projects') ($slots -join ' ; ')
        $work = $false
        foreach ($k in Get-ChildItem "$script:TCRoot\Plugins Configuration\FTP\Bookmarks" -ErrorAction SilentlyContinue) { if ((Get-ItemProperty $k.PSPath).Name -eq 'Work') { $work = $true } }
        Check 'U1 imported FTP bookmark stored after exit' $work ''
    }

    # ---------------------------------------------------------------- U2 cancel on every page
    New-TCConfig $Exe $OutDir | Out-Null
    $m0 = Get-RegMap $script:TCRoot
    $maxPage = if ($Release) { 1 } else { 4 }
    for ($page = 1; $page -le $maxPage; $page++) {
        $p = Start-TC
        $main = Main-Of $p
        [void][Ui245]::PostMessageW($main, $WM_COMMAND, [IntPtr]$CM_IMPORT, [IntPtr]::Zero)
        $d = Wait-Dialog $p 'Import Settings from Salamander*'
        for ($k = 1; $k -lt $page -and $d -ne [IntPtr]::Zero; $k++) {
            Click $d $IDOK
            [void](Gone $d)
            $d = Wait-Dialog $p 'Import Settings from Salamander*' 30
        }
        $ok = $d -ne [IntPtr]::Zero
        if ($ok) { Click $d $IDCANCEL; [void](Gone $d) }
        Stop-TC $p
        Check "U2 cancel on page $page" $ok ''
    }
    $m1 = Get-RegMap $script:TCRoot
    $changed = @($m0.Keys | Where-Object { -not $_.StartsWith('Window|') -and -not $_.StartsWith('Left Panel') -and -not $_.StartsWith('Right Panel') -and -not $_.StartsWith('Plugins Order') -and ($m1[$_] -ne $m0[$_]) })
    $extra = @($m1.Keys | Where-Object { -not $m0.ContainsKey($_) -and -not $_.StartsWith('Plugins Order') })
    Check 'U2 cancel changed nothing' ($changed.Count -eq 0 -and $extra.Count -eq 0) ("changed=" + ($changed -join ', ') + " extra=" + ($extra -join ', '))

    # ---------------------------------------------------------------- U3 dark theme captures
    if (-not $Release) {
        Set-RegTree $script:TCRoot @{ 'Configuration' = @{ 'Theme Mode' = 1 } }
        $p = Start-TC
        $main = Main-Of $p
        [void][Ui245]::PostMessageW($main, $WM_COMMAND, [IntPtr]$CM_IMPORT, [IntPtr]::Zero)
        $d = Wait-Dialog $p 'Import Settings from Salamander'
        if ($d -ne [IntPtr]::Zero) {
            Snap $d 'u3_dark_page1.png'
            Click $d $IDOK; [void](Gone $d)
            $d = Wait-Dialog $p 'Import Settings from Salamander'
            if ($d -ne [IntPtr]::Zero) { Snap $d 'u3_dark_page2.png'; Click $d $IDCANCEL; [void](Gone $d) }
        }
        Stop-TC $p
        Check 'U3 dark theme pages captured' (Test-Path (Join-Path $OutDir 'u3_dark_page2.png')) 'NOT DRIVEN: the colours are judged by a person'
    }

    # ---------------------------------------------------------------- U4/U5 first-start offer
    if (-not $Release) {
        foreach ($answer in @('no', 'yes')) {
            if (Test-Path $script:TCPS) { Remove-Item -LiteralPath $script:TCPS -Recurse -Force }
            $p = Start-TC
            # the first start of a fresh configuration asks for the language first
            $lang = Wait-Dialog $p '*' 20
            $offer = [IntPtr]::Zero
            $end = (Get-Date).AddSeconds(30)
            while ((Get-Date) -lt $end -and $offer -eq [IntPtr]::Zero) {
                foreach ($h in [Ui245]::Tops([uint32]$p.Id)) {
                    if ([Ui245]::Cls($h) -ne '#32770') { continue }
                    # the offer is the Yes/No box (a fresh configuration picks the system's language,
                    # so its text is not matched here)
                    if ([Ui245]::GetDlgItem($h, $IDYES) -ne [IntPtr]::Zero -and [Ui245]::GetDlgItem($h, $IDNO) -ne [IntPtr]::Zero) { $offer = $h; break }
                    if ([Ui245]::GetDlgItem($h, $IDOK) -ne [IntPtr]::Zero) { Click $h $IDOK } # language / other first-start boxes
                }
                Start-Sleep -Milliseconds 300
            }
            Check "U4 offer shown at the first start ($answer)" ($offer -ne [IntPtr]::Zero) ''
            if ($offer -ne [IntPtr]::Zero) {
                Snap $offer "u4_offer_$answer.png"
                Click $offer $(if ($answer -eq 'no') { $IDNO } else { $IDYES })
                [void](Gone $offer)
                if ($answer -eq 'yes') {
                    $w = [IntPtr]::Zero
                    $end2 = (Get-Date).AddSeconds(15)
                    while ((Get-Date) -lt $end2 -and $w -eq [IntPtr]::Zero) { # page 1 by its list box (any language)
                        foreach ($h in [Ui245]::Tops([uint32]$p.Id)) { if ([Ui245]::Cls($h) -eq '#32770' -and [Ui245]::GetDlgItem($h, $IDC_SOURCES) -ne [IntPtr]::Zero) { $w = $h } }
                        Start-Sleep -Milliseconds 200
                    }
                    Check 'U5 Import now opens the wizard' ($w -ne [IntPtr]::Zero) ''
                    if ($w -ne [IntPtr]::Zero) { Click $w $IDCANCEL; [void](Gone $w) }
                }
            }
            Check "U4 configuration saved after the answer ($answer)" (Test-Path "$script:TCRoot\Configuration") ''
            Stop-TC $p
            # a second start: no offer
            $p = Start-TC
            $main = Main-Of $p
            Start-Sleep -Seconds 6
            $again = @([Ui245]::Tops([uint32]$p.Id) | Where-Object { [Ui245]::Cls($_) -eq '#32770' -and [Ui245]::GetDlgItem($_, $IDYES) -ne [IntPtr]::Zero })
            Check "U4 no offer at the next start ($answer)" ($again.Count -eq 0) ''
            Stop-TC $p
        }
    }
}
finally {
    Remove-Fixtures
    Get-Process tandemcommander -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Kill() } catch {} }
    Restore-TC $backup $existed
    $after0 = Get-RegDump $script:TCPS
    Check 'registry restored' ((($before0 -join "`n") -eq ($after0 -join "`n"))) ''
    $script:Results | Set-Content -LiteralPath $OutFile -Encoding UTF8
    Write-Output "FAILED: $script:Fails"
}
