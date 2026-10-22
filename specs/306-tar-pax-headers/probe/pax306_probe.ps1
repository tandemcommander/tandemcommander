<#
.SYNOPSIS
    Feature 306 (backlog item tar-plug-in-ignores-pax-extended-headers): a tar member preceded by a PAX
    extended header (type 'x') is listed and extracted under the header's path, with its size and
    time; a global header (type 'g') applies to the following members; a PAX path no file system
    takes is refused, never cut.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\t.tar made by Python's tarfile through
    mkpax306.py (next to this script; PAX format, GNU format for the GNU-* rows) and <row>\tgt, an
    empty folder. The left panel opens t.tar, the right panel shows tgt; Select All (842), Copy (727,
    dialogs answered OK). CJK(n) = n letters U+4E00, U+4E01, ...
      PAX-LONG     d*100/e*100/f*96.txt (302 bytes; ustar keeps the first 100 bytes)     -> that path, 'L'
      PAX-CJK      CJK(200).txt (ustar: 100 '?')                                          -> that name, 'C'
      PAX-TWINS    CJK(199)+U+5000.txt 'A', CJK(199)+U+5001.txt 'B' (same ustar name)     -> both
      PAX-DEEP     sub/CJK(200).txt                                                       -> that path, 'D'
      PAX-MTIME    t.txt, ustar mtime 1000000000, PAX mtime=1600000000.25                 -> time 1600000000.25
      PAX-SIZE     s.txt 'SIZE5' with ustar size 0 and PAX size=5, then z.txt 'Z'          -> both whole
      PAX-GLOBAL   'g' header mtime=1500000000; g.txt (ustar 1000000000); h.txt with PAX
                   mtime=1400000000                                                       -> 1500000000 / 1400000000
      GIT-COMMENT  'g' header comment=<40 hex> (git archive); a.txt                       -> a.txt 'A', 1000000000
      GNU-LONG     PAX-LONG's path as a GNU long name (regression)                        -> that path, 'L'
      PAX-TOOLONG  CJK(300).txt (300 UTF-16 units: no file system takes it), then ok.txt 'K'
                                                                -> "(206)" message at open, tgt holds only ok.txt
      GNU-TOOLONG  CJK(300).txt as a GNU long name - only with -Only GNU-TOOLONG: it crashes the program
                   (measured before feature 306; an Inbox defect outside it)      -> tgt empty, a message
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\273-tar-case-root\probe\arccase273_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc306'
$StartDir = $Root + '\start'
$MkPax = Join-Path $Here 'mkpax306.py'

function Cjk([int]$n, [int]$start = 0x4E00) { $sb = New-Object Text.StringBuilder; for ($i = 0; $i -lt $n; $i++) { [void]$sb.Append([char]($start + $i)) }; return $sb.ToString() }
function Start-Arc([string]$Left, [string]$Right) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T306', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2000
    $r = Serve $p.Id 10
    $script:OpenMsgs = Msgs $r
    return $p.Id
}
# the files under tgt, relative, '/'-separated
function Tgt-Files([string]$Tgt) {
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) }
# the file's write time as seconds since 1970 (UTC), with the 100-ns fraction
function UnixTime([string]$Tgt, [string]$Rel) {
    $t = [IO.File]::GetLastWriteTimeUtc($LP + $Tgt + '\' + $Rel.Replace('/', '\'))
    return ($t.Ticks - 621355968000000000) / 10000000.0
}
function Short([string]$s) { if ($s.Length -le 24) { return $s }; return ('{0}..[{1} chars]..{2}' -f $s.Substring(0, 8), $s.Length, $s.Substring($s.Length - 8)) }
function Esc-Names($files) { return (@($files | ForEach-Object { Esc (Short $_) }) -join ', ') }

function Run-Row([string]$name) {
    if (-not (Want $name)) { return }
    $d = $Root + '\' + $name
    $tgt = $d + '\tgt'; $arc = $d + '\t.tar'
    $longPath = ('d' * 100) + '/' + ('e' * 100) + '/' + ('f' * 96) + '.txt'
    # expected: relative path -> @(content, unix time or $null)
    $want = [ordered]@{}; $refuse = $false
    switch ($name) {
        'PAX-LONG' { $want[$longPath] = @('L', 1000000000) }
        'GNU-LONG' { $want[$longPath] = @('L', 1000000000) }
        'PAX-CJK' { $want[(Cjk 200) + '.txt'] = @('C', 1000000000) }
        'PAX-TWINS' { $want[(Cjk 199) + [char]0x5000 + '.txt'] = @('A', $null); $want[(Cjk 199) + [char]0x5001 + '.txt'] = @('B', $null) }
        'PAX-DEEP' { $want['sub/' + (Cjk 200) + '.txt'] = @('D', $null) }
        'PAX-MTIME' { $want['t.txt'] = @('T', 1600000000.25) }
        'PAX-SIZE' { $want['s.txt'] = @('SIZE5', $null); $want['z.txt'] = @('Z', $null) }
        'PAX-GLOBAL' { $want['g.txt'] = @('G', 1500000000); $want['h.txt'] = @('H', 1400000000) }
        'GIT-COMMENT' { $want['a.txt'] = @('A', 1000000000) }
        default { $refuse = $true }
    }
    try {
        NewDir $d; NewDir $tgt
        $o = & $Python -I $MkPax $name $arc 2>&1
        if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    }
    catch { Row $name 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $arc) }
        $id = Start-Arc $arc $tgt
        $openMsgs = $script:OpenMsgs
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 40 @(1, 6)
        $msgs = Msgs $r
        End-Row $name $id $null $before; $id = 0
        $files = @(Tgt-Files $tgt)
        $facts = New-Object System.Collections.ArrayList
        if ($name -eq 'PAX-TOOLONG') {
            # the system's "(206) file name too long" when the archive is opened, the long member not
            # created under any name, the other member extracted
            $msgOk = $openMsgs -match '\(206\)'
            $okC = '-'; if ($files -ccontains 'ok.txt') { $okC = Content $tgt 'ok.txt' }
            $ok = $msgOk -and ($files.Count -eq 1) -and ($okC -ceq 'K')
            [void]$facts.Add(('message (206) at open: {0}; ok.txt: {1}; tgt: {2}' -f $msgOk, $okC, $(if ($files.Count) { Esc-Names $files } else { 'empty' })))
        }
        elseif ($refuse) {
            $other = @($r.Messages | Where-Object { $_ -notmatch "^\[#32770 'Copy'\]" })
            $ok = ($files.Count -eq 0) -and (($other.Count + $(if ($openMsgs -ne 'no window') { 1 } else { 0 })) -gt 0)
            [void]$facts.Add('tgt: ' + $(if ($files.Count) { Esc-Names $files } else { 'empty' }))
        }
        else {
            $ok = ($files.Count -eq $want.Count)
            foreach ($k in $want.Keys) {
                if ($files -notcontains $k) { $ok = $false; [void]$facts.Add('missing ' + (Esc (Short $k))); continue }
                $c = Content $tgt $k
                $t = UnixTime $tgt $k
                $exp = $want[$k]
                $cOk = ($c -ceq $exp[0]); $tOk = ($null -eq $exp[1]) -or ([math]::Abs($t - [double]$exp[1]) -lt 0.00001)
                if (-not ($cOk -and $tOk)) { $ok = $false }
                [void]$facts.Add(('{0}: {1} t={2}' -f (Esc (Short $k)), $c, $t))
            }
            [void]$facts.Add('tgt: ' + $(if ($files.Count) { Esc-Names $files } else { 'empty' }))
        }
        Row $name 'RUN' (V $ok) (($facts -join '; ') + '; at open: ' + (Tail $openMsgs 120) + '; windows: ' + (Tail $msgs 220))
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $name $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc306_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("pax306_probe (feature 306) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    $rowNames = @('PAX-LONG', 'PAX-CJK', 'PAX-TWINS', 'PAX-DEEP', 'PAX-MTIME', 'PAX-SIZE', 'PAX-GLOBAL', 'GIT-COMMENT', 'GNU-LONG', 'PAX-TOOLONG')
    # GNU-TOOLONG crashes the program (the Inbox defect, outside feature 306): only with -Only GNU-TOOLONG
    if ($Only -and @($Only | Where-Object { 'GNU-TOOLONG' -like ($_ + '*') }).Count) { $rowNames += 'GNU-TOOLONG' }
    foreach ($n in $rowNames) { Run-Row $n }
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
