<#
.SYNOPSIS
    Feature 163 probe: the item a command selects for the time of its dialog (nothing selected -
    the focused item) is unselected afterwards, also when its UTF-8 name has 260 bytes or more.

.DESCRIPTION
    SelectFocusedItemAndGetName copied the focused name into char[MAX_PATH] and cut it there;
    UnselectItemWithName then found no item of the cut name, and the item STAYED SELECTED after
    the dialog - the next Delete with the focus on another file asked about (and would delete)
    that item. A row: a folder with a.dat and the name under test; the name is focused (Change
    Directory to it), the command's dialog opens and is cancelled; the focus goes to a.dat (Home,
    Down); Delete (F8, command 729) - its question must name a.dat alone; answered No / Cancel.
      <cmd>-LONG   140 x c-caron + ".dat" (284 bytes, 144 characters)        a.dat      the long name
      <cmd>-SHORT  "c-caron-s-caron.dat" (control: fits)                    a.dat      a.dat
    Commands: QREN Quick Rename (754), ATTR Change Attributes (748), CASE Change Case (747).
    English UI (Set-Config), no Recycle Bin, delete confirmation on (the first runs sent the
    deleted *.txt fixtures to the user's Recycle Bin - "Use Recycle Bin For *.txt"). Every file
    is checked to exist afterwards.

    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [switch]$Diag
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs'); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc163'
$StartDir = $Root + '\start'
$Sc = [string][char]0x0161
$LongName = ($Cc * 140) + '.dat'
$ShortName = $Cc + $Sc + '.dat'

# the left panel's list (the probe starts the program with the folder under test on the left): the
# list window with the smaller screen x - Get-LeftList takes the first in window order
function Left-List([int]$Id) {
    $best = [IntPtr]::Zero; $bx = [int]::MaxValue
    foreach ($h in @([Drv098f]::Kids((Get-Main $Id)) | Where-Object { [Drv098f]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv098f]::IsWindowVisible($_) })) {
        $r = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($h, [ref]$r)
        if ($r.Left -lt $bx) { $bx = $r.Left; $best = $h }
    }
    if ($best -eq [IntPtr]::Zero) { throw 'panel list window not found' }
    return $best
}
function LKey([int]$Id, [int]$Vk) {
    $l = Left-List $Id
    [void][Drv098f]::Send($l, 0x0100, $Vk, 1, 30000)
    [void][Drv098f]::Send($l, 0x0101, $Vk, 0xC0000001, 30000)
}
function Has([string]$p) { return [IO.File]::Exists($LP + $p) }
function Run-Case([string]$Case, [int]$Cmd, [string]$Name) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case; NewDir $d
    WriteFile ($d + '\a.dat') 'a'
    WriteFile ($d + '\' + $Name) 'n'
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        $held = Do-ChangeDir $id ($d + '\' + $Name)                      # focuses the name
        [void](Serve $id 5 @(2))
        $dlg = Open-ByCmd $id $Cmd 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'DELETE' 'NOT DRIVEN' ('command ' + $Cmd + ' opened no window'); return }
        $what = WinDesc $dlg
        Close-Win $dlg
        [void](Serve $id 5 @(2))
        LKey $id 0x24; LKey $id 0x28                                       # Home (..), Down (a.dat)
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 729                                       # Delete
        $q = Wait-NewWin $id $known 10
        if ($Diag) {
            $all = @([Drv098f]::Top([uint32]$id) | ForEach-Object { [Drv098f]::Cls($_) + "'" + (Tail ([Drv098f]::Txt($_)) 40) + "' vis " + [Drv098f]::IsWindowVisible($_) })
            Out ('  diag: windows after F8: ' + ($all -join ' ; ') + '; a.dat ' + (Has ($d + '\a.dat')) + ', name ' + (Has ($d + '\' + $Name)))
        }
        $text = $(if ($q -ne [IntPtr]::Zero) { FullText $q } else { '' })
        if ($q -ne [IntPtr]::Zero) {
            $no = Buttons $q | Where-Object { @(7, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($no) { Click $no } else { Close-Win $q }
        }
        $r = Serve $id 5 @(2, 7)
        $both = (Has ($d + '\a.dat')) -and (Has ($d + '\' + $Name))
        $namesA = $text -match 'a\.dat'
        $namesOther = $text.Contains($Cc + $Cc + $Cc) -or $text.Contains($ShortName) -or $text -match '\b2\b'
        if ($q -eq [IntPtr]::Zero) { $v = 'FAIL'; $asked = 'no question' }
        else { $v = V ($namesA -and -not $namesOther -and $both); $asked = Tail $text 120 }
        Row $Case 'DELETE' $v ("{0} ({1} bytes, field held it {2}); dialog {3} cancelled; Delete with the focus on a.dat asked: {4}; files kept {5}; after: {6}" -f $(if ($Name.Length -gt 20) { 'long name' } else { 'short name' }), (U8Len $Name), $held, (Tail $what 50), $asked, $both, (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc163_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    # no Recycle Bin: a probe's deleted fixture must not land in the user's bin (restored at the end)
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Use Recycle Bin' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Files or Dirs Del' /t REG_DWORD /d 1 /f | Out-Null
    Out ("temp_selection_probe (feature 163), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash)
    Out ''
    foreach ($c in @(@('QREN', 754), @('ATTR', 748), @('CASE', 747))) {
        Run-Case ($c[0] + '-LONG') $c[1] $LongName
        Run-Case ($c[0] + '-SHORT') $c[1] $ShortName
    }
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
if ($Expect -eq 'before') { exit 0 }
exit $nf
