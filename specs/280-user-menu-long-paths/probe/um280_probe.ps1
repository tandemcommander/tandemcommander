<#
.SYNOPSIS
    Feature 280 probe: every User Menu route with an item whose folder or full name has 260 or more
    bytes either runs the command on the whole name or refuses with "too long name" before anything
    runs - never acts on, or shows, a cut path.

.DESCRIPTION
    Fixture (under %TEMP%\tc280): s\a.txt and s\<L>.txt (L = 90 CJK letters, 270 bytes of UTF-8);
    pl\<L>\a.txt (a folder of about 310 bytes); pc\<P>\b\a.txt where <root>\pc\<P>\ is exactly 259 bytes
    (the folder pc\<P>\b is 260 bytes: a cut at 259 bytes ends right after a backslash - its parent).
    User Menu items (seeded; the command writes its expanded arguments to <root>\out\<item>.txt with
    "cmd /u /c echo", UTF-16):
      FULLNAME   cmd.exe /u /c echo [$(FullName)]           direct (ShellExecuteEx)
      FULLBAT    echo [$(FullName)]                          through a batch file
      FPR        cmd.exe /u /c echo [$(FullPathRight)]      direct
      LISTFULL   cmd.exe /u /c echo [$(ListOfSelectedFullNames)]  direct
      CMPL       cmd.exe /u /c echo [$(FileToCompareLeft)][$(FileToCompareRight)]  direct
    Rows (PASS = the expected outcome after the fix; "too long" = a window with "too long name"):
      CONTROL    s, a.txt focused, FULLNAME: out holds [<root>\s\a.txt]
      SHORTTWO   s2 (a.txt, b.txt), both selected, PERNAME (direct, one output file per item):
                 both items ran (control of the prepared runs)
      FPRSHORT   right panel s, FPR: out holds [<root>\s\] (control of the full path)
      LDIRFOCUS  pl\<L>, a.txt focused, FULLNAME: "too long", no out (feature 225)
      LDIRSEL    pl\<L>, a.txt selected, FULLNAME: "too long", no out
      LNAME      s, <L>.txt focused, FULLNAME: "too long", no out
      MIXDIRECT  s, a.txt and <L>.txt selected, FULLNAME (direct): "too long", no out (nothing ran)
      MIXBAT     the same through a batch file: "too long", no out
      FPRCUT     right panel pc\<P>\b (260 bytes), left active on s\a.txt, FPR: "too long", no out
                 (before: the command got the parent folder <root>\pc\<P>\)
      FPRLONG    right panel pl\<L>, FPR: "too long", no out (before: "not defined")
      LISTFULL   s, a.txt and <L>.txt selected, LISTFULL: out holds both whole full names
      CMPLONG    both panels s, <L>.txt focused, CMPL: "too long", no compare-names dialog, no out
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1'
if (-not (Test-Path -LiteralPath $lib)) { $lib = 'E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $lib
$Root = $TempRoot + '\tc280'
$StartDir = $Root + '\s'
$OutDir = $Root + '\out'
$S2 = $Root + '\s2'
$L =-join (1..90 | ForEach-Object { [char](0x4E00 + $_) })
$LDir = $Root + '\pl\' + $L
$PcDir = $Root + '\pc'
$pLen = 258 - (U8Len ($PcDir + '\'))
$P = 'p' * $pLen
$CutDir = $PcDir + '\' + $P + '\b'
$UmKey = 'Software\Tandem Commander\0.1\User Menu'
$Unicode = New-Object Text.UnicodeEncoding($false, $false)

# item -> command, arguments, through a shell (index = position - 1)
$Items = [ordered]@{
    'FULLNAME' = @('cmd.exe', '/u /c echo [$(FullName)]>>"{OUT}"', 0)
    'PERNAME'  = @('cmd.exe', '/u /c echo [$(FullName)]>"{OUTDIR}\PERNAME-$(Name).txt"', 0)
    'FULLBAT'  = @('echo', '[$(FullName)]>>"{OUT}"', 1)
    'FPR'      = @('cmd.exe', '/u /c echo [$(FullPathRight)]>>"{OUT}"', 0)
    'LISTFULL' = @('cmd.exe', '/u /c echo [$(ListOfSelectedFullNames)]>>"{OUT}"', 0)
    'CMPL'     = @('cmd.exe', '/u /c echo [$(FileToCompareLeft)][$(FileToCompareRight)]>>"{OUT}"', 0)
}
$ItemIndex = @{}
function Seed-UserMenu {
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($UmKey, $false)
    $i = 0
    foreach ($c in $Items.Keys) {
        $ItemIndex[$c] = $i
        $i++
        $v = $Items[$c]
        $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($UmKey + '\' + $i)
        $k.SetValue('Item Name', ('tc280 ' + $c), 'String'); $k.SetValue('Command', $v[0], 'String')
        $k.SetValue('Arguments', $v[1].Replace('{OUT}', $OutDir + '\' + $c + '.txt').Replace('{OUTDIR}', $OutDir), 'String'); $k.SetValue('Initial Directory', '', 'String')
        $k.SetValue('Execute Through Shell', $v[2], 'DWord'); $k.SetValue('Close Shell Window', 1, 'DWord'); $k.SetValue('Open Shell Window', 0, 'DWord')
        $k.SetValue('Icon', '', 'String'); $k.SetValue('Type', 0, 'DWord'); $k.SetValue('Show In Toolbar', 0, 'DWord')
        $k.Close()
    }
}
function Clear-Out { foreach ($f in @([IO.Directory]::GetFiles($LP + $OutDir))) { [IO.File]::Delete($f) } }
function Read-Out([string]$Item) {
    $f = $LP + $OutDir + '\' + $Item + '.txt'
    if (-not [IO.File]::Exists($f)) { return $null }
    $b = [IO.File]::ReadAllBytes($f)
    if ($b.Length -ge 2 -and $b[1] -eq 0) { return $Unicode.GetString($b).TrimEnd("`r", "`n") }
    return $Utf8.GetString($b).TrimEnd("`r", "`n")
}
function Wait-Out([string]$Item, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and -not [IO.File]::Exists($LP + $OutDir + '\' + $Item + '.txt')) { Start-Sleep -Milliseconds 250 }
    Start-Sleep -Milliseconds 700
    return (Read-Out $Item)
}
# the panel list windows, left first
function Get-Lists([int]$Id) {
    $lists = @([Drv098f]::Kids((Get-Main $Id)) | Where-Object { [Drv098f]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv098f]::IsWindowVisible($_) })
    return @($lists | Sort-Object { $r = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($_, [ref]$r); $r.Left })
}
function KeyTo([IntPtr]$List, [int]$Vk) {
    [void][Drv098f]::Send($List, 0x0100, $Vk, 1, 30000)
    [void][Drv098f]::Send($List, 0x0101, $Vk, 0xC0000001, 30000)
}
function Start-Two([string]$Left, [string]$Right, [int]$Active) {
    $a = @('-t', 'T280', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', [string]$Active)
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2000
    [void](Serve $p.Id 10)
    return $p.Id
}
# enters the only sub-folder of the panel's folder (Home = "..", Down = the folder, Enter)
function Enter-Only([IntPtr]$List) { KeyTo $List 0x24; KeyTo $List 0x28; KeyTo $List 0x0D; Start-Sleep -Milliseconds 800 }
function Short($s) { if ($null -eq $s) { return 'missing' }; return ("'" + (Tail $s 60) + "' (" + (U8Len $s) + ' bytes)') }

# Setup: a function that prepares the panels of the started instance; Item: the User Menu item;
# Expect: 'refuse' or a scriptblock that checks the output text
function Run-Row([string]$Case, [string]$Left, [string]$Right, [int]$Active, [scriptblock]$Setup, [string]$Item, $Expect, [int[]]$Want = @(1, 6)) {
    if (-not (Want $Case)) { return }
    Clear-Out
    $id = 0; $before = Reports
    try {
        $id = Start-Two $Left $Right $Active
        $lists = Get-Lists $id
        if ($lists.Count -lt 2) { throw 'two panel lists not found' }
        $where = & $Setup $id $lists
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) (3000 + $ItemIndex[$Item])
        $r = Serve $id 25 $Want
        $got = Wait-Out $Item 4
        $msgs = Msgs $r
        $told = $msgs -match 'too long name'
        $dialog = $msgs -match 'Compare'
        if ($Expect -is [string]) { $ok = $told -and ($null -eq $got) -and -not $dialog }
        else { $ok = (& $Expect $got) -and -not $told }
        Row $Case 'RUN' (V $ok) ("{0}; out {1}; windows: {2}" -f $where, (Short $got), (Tail $msgs 220))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc280_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir; NewDir $LDir; NewDir $CutDir; NewDir $S2
    WriteFile ($S2 + '\a.txt') 'A'; WriteFile ($S2 + '\b.txt') 'B'
    WriteFile ($StartDir + '\a.txt') 'A'; [IO.File]::WriteAllText($LP + $StartDir + '\' + $L + '.txt', 'L')
    WriteFile ($LDir + '\a.txt') 'A'; WriteFile ($CutDir + '\a.txt') 'A'
    Set-Config
    Seed-UserMenu
    Out ("um280_probe (feature 280) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ("Fixture : root {0} bytes; long folder {1} bytes; cut folder {2} bytes (its parent + backslash {3} bytes); long name {4} bytes" -f (U8Len $Root), (U8Len $LDir), (U8Len $CutDir), (U8Len ($PcDir + '\' + $P + '\')), (U8Len ($L + '.txt')))
    Out ''

    $sA = $StartDir + '\a.txt'
    $sL = $StartDir + '\' + $L + '.txt'
    # focus a.txt / <L>.txt in the left panel of s (".." first, then a.txt, then <L>.txt)
    $focusA = { param($id, $lists) KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x28; 'left s, a.txt focused' }
    $focusL = { param($id, $lists) KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x23; 'left s, <L>.txt focused' }
    $selBoth = { param($id, $lists) KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x28; KeyTo $lists[0] 0x2D; KeyTo $lists[0] 0x2D; 'left s, a.txt + <L>.txt selected' }
    $ldirFocus = { param($id, $lists) Enter-Only $lists[0]; $loc = Get-Loc $id; KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x23; ('left ' + (U8Len $loc) + ' bytes, a.txt focused') }
    $ldirSel = { param($id, $lists) Enter-Only $lists[0]; $loc = Get-Loc $id; KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x28; KeyTo $lists[0] 0x2D; ('left ' + (U8Len $loc) + ' bytes, a.txt selected') }
    $rightCut = { param($id, $lists) Enter-Only $lists[1]; Enter-Only $lists[1]; $loc = Get-Loc $id; KeyTo $lists[1] 0x09; KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x28; ('right ' + (U8Len $loc) + ' bytes, left active on a.txt') }
    $rightLong = { param($id, $lists) Enter-Only $lists[1]; $loc = Get-Loc $id; KeyTo $lists[1] 0x09; KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x28; ('right ' + (U8Len $loc) + ' bytes, left active on a.txt') }

    Run-Row 'CONTROL' $StartDir $StartDir 1 $focusA 'FULLNAME' { param($g) $g -ceq ('[' + $sA + ']') }
    # controls of the changed routes: two short items without a shell both run, in order; a short
    # right panel gives its folder with a backslash
    $selTwo = { param($id, $lists) KeyTo $lists[0] 0x24; KeyTo $lists[0] 0x28; KeyTo $lists[0] 0x2D; KeyTo $lists[0] 0x2D; 'left s2, a.txt + b.txt selected' }
    Run-Row 'SHORTTWO' $S2 $StartDir 1 $selTwo 'PERNAME' { param($g) ((Read-Out 'PERNAME-a.txt') -ceq ('[' + $S2 + '\a.txt]')) -and ((Read-Out 'PERNAME-b.txt') -ceq ('[' + $S2 + '\b.txt]')) }
    Run-Row 'FPRSHORT' $StartDir $StartDir 1 $focusA 'FPR' { param($g) $g -ceq ('[' + $StartDir + '\]') }
    Run-Row 'LDIRFOCUS' ($Root + '\pl') $StartDir 1 $ldirFocus 'FULLNAME' 'refuse'
    Run-Row 'LDIRSEL' ($Root + '\pl') $StartDir 1 $ldirSel 'FULLNAME' 'refuse'
    Run-Row 'LNAME' $StartDir $StartDir 1 $focusL 'FULLNAME' 'refuse'
    Run-Row 'MIXDIRECT' $StartDir $StartDir 1 $selBoth 'FULLNAME' 'refuse'
    Run-Row 'MIXBAT' $StartDir $StartDir 1 $selBoth 'FULLBAT' 'refuse'
    Run-Row 'FPRCUT' $StartDir $PcDir 2 $rightCut 'FPR' 'refuse'
    Run-Row 'FPRLONG' $StartDir ($Root + '\pl') 2 $rightLong 'FPR' 'refuse'
    Run-Row 'LISTFULL' $StartDir $StartDir 1 $selBoth 'LISTFULL' { param($g) $g -ceq ('[' + $sA + ' ' + $sL + ']') -or $g -ceq ('[' + $sA + ' "' + $sL + '"]') }
    Run-Row 'CMPLONG' $StartDir $StartDir 1 $focusL 'CMPL' 'refuse' @(2)
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
