<#
.SYNOPSIS
    Feature 245 end-to-end matrix (quickstart V2): every scenario starts from a fresh product
    configuration and fixture sources, runs the Debug build with the import automation seam and
    compares the registry before and after. Writes one line per check to -OutFile.

.DESCRIPTION
    S0  noise baseline: what a start/exit cycle alone changes (excluded from "unchanged" checks)
    S1  defaults (Add): items added, 0 existing values changed (SC-010), source unchanged (SC-002)
    S2  Replace / take over with consent: groups equal the source's, TC-owned values unchanged
    S3  S1 twice: nothing added twice (SC-005)
    S5  Replace without consent: not applied, nothing changed
    S6  old/new configuration versions: '$' doubling (< 47), lower-case masks (< 44), refusals
    S7  passwords: scrambled, AES with right/wrong master password, weaker-storage consent,
        a program master password (SC-009)
    S8  plugin shortcuts: added, a TC key refused, a current key kept
    S9  another instance running: refused
    S10 backup: -C <backup> restores the pre-import configuration (SC-008)
    S11 non-ASCII names unchanged (FR-007)
    MUST run through tools\run_on_hidden_desktop.ps1. The product key is exported first and
    restored + verified at the end; the fixtures are removed.
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$OutFile,
    [string]$Only = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ci245_lib.ps1')
. (Join-Path $PSScriptRoot 'ci245_fixtures.ps1')
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (-not $OutFile) { $OutFile = Join-Path $OutDir 'result_e2e.txt' }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$backup = Join-Path $OutDir 'tc_backup.reg'
$existed = Backup-TC $backup
$before0 = Get-RegDump $script:TCPS
$CZ = ([string][char]0x010D + 'esky')
$ZL = ('D:\' + [char]0x017D + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k')

function Want([string]$s) { return ($Only -eq '' -or (",$Only," -like "*,$s,*")) }

# list items of a key (numeric subkeys) as fingerprints
function Get-Items([string]$PSPath) {
    $r = @()
    if (-not (Test-Path -LiteralPath $PSPath)) { return $r }
    foreach ($k in (Get-ChildItem -LiteralPath $PSPath | Where-Object { $_.PSChildName -match '^\d+$' } | Sort-Object { [int]$_.PSChildName })) {
        $parts = @()
        foreach ($n in ($k.GetValueNames() | Sort-Object)) {
            $v = $k.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
            if ($v -is [byte[]]) { $v = 'bin' + $v.Length }
            $parts += "$n=$v"
        }
        $r += ($parts -join ';')
    }
    return $r
}
function Get-Slots {
    $h = @{}
    $p = "$script:TCRoot\Hot Paths"
    if (Test-Path $p) { foreach ($k in Get-ChildItem $p) { $v = Get-ItemProperty $k.PSPath; $h[[int]$k.PSChildName] = "$($v.Name)|$($v.Path)|$($v.Visible)" } }
    return $h
}
function Get-Val([string]$Sub, [string]$Name) {
    $p = Join-Path $script:TCRoot $Sub
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $k = Get-Item -LiteralPath $p
    return $k.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
}
function Find-Bookmark([string]$Name) {
    $p = "$script:TCRoot\Plugins Configuration\FTP\Bookmarks"
    if (-not (Test-Path $p)) { return $null }
    foreach ($k in Get-ChildItem $p) { if ((Get-ItemProperty $k.PSPath).Name -eq $Name) { return $k } }
    return $null
}
function Find-Proxy([string]$Name) {
    $p = "$script:TCRoot\Plugins Configuration\FTP\Proxy Servers"
    if (-not (Test-Path $p)) { return $null }
    foreach ($k in Get-ChildItem $p) { if ((Get-ItemProperty $k.PSPath).Name -eq $Name) { return $k } }
    return $null
}
function TCPluginNumber([string]$Dll) {
    foreach ($k in Get-ChildItem "$script:TCRoot\Plugins") { if ((Get-ItemProperty $k.PSPath).DLL -eq $Dll) { return [int]$k.PSChildName } }
    return -1
}
function Get-PluginDlls { return @(Get-ChildItem "$script:TCRoot\Plugins" | Sort-Object { [int]$_.PSChildName } | ForEach-Object { (Get-ItemProperty $_.PSPath).DLL }) -join ',' }
function Decode([byte[]]$Blob, [string]$Master = '') {
    $hex = -join ($Blob | ForEach-Object { $_.ToString('x2') })
    $r = Invoke-TC $Exe "[fixture]`r`ndecode=$hex`r`ndecodemaster=$Master`r`n" $OutDir 'decode' 60 'Software\Tandem Commander Test 245 Empty'
    if ($r.Fixture -match '^P (.*)') { return $Matches[1].TrimEnd() }
    return $null
}
# values of 'before' that differ in 'after' (or vanished), keys under $Prefixes are ignored (lists that grow)
function Changed-Values($Before, $After, [string[]]$Ignore) {
    $out = @()
    foreach ($k in $Before.Keys) {
        $skip = $false
        foreach ($p in $Ignore) { if ($k.StartsWith($p)) { $skip = $true; break } }
        if ($skip) { continue }
        if (-not $After.ContainsKey($k) -or $After[$k] -ne $Before[$k]) { $out += $k }
    }
    return $out
}
function Source-Dump { return (Get-RegDump $script:FixPS) -join "`n" }

try {
    Remove-Fixtures
    # ---------------------------------------------------------------- S0 noise
    New-TCConfig $Exe $OutDir | Out-Null
    $d0 = Get-RegMap $script:TCRoot
    New-AltapFixture | Out-Null
    $r = Invoke-TC $Exe "[import]`r`ngroups=none`r`n" $OutDir 's0a'
    $d1 = Get-RegMap $script:TCRoot
    $r = Invoke-TC $Exe "[import]`r`ngroups=none`r`n" $OutDir 's0b'
    $d2 = Get-RegMap $script:TCRoot
    $noise = @{}
    foreach ($k in $d0.Keys) { if (-not $d1.ContainsKey($k) -or $d1[$k] -ne $d0[$k] -or -not $d2.ContainsKey($k) -or $d2[$k] -ne $d0[$k]) { $noise[$k] = 1 } }
    foreach ($k in $d1.Keys + $d2.Keys) { if (-not $d0.ContainsKey($k)) { $noise[$k] = 1 } } # created by the second start (e.g. Plugins Order)
    Check 'S0 noise baseline' $true ("values changed by a start/exit cycle: " + ($noise.Keys -join ', '))
    $noisePrefixes = @($noise.Keys | ForEach-Object { $_ })
    $ownBefore = @{}
    foreach ($n in 'Theme Mode', 'Panel Tabs', 'Quick Search Filter', 'Language', 'Command Shell Preset') { $ownBefore[$n] = Get-Val 'Configuration' $n }

    # ---------------------------------------------------------------- S1 defaults (Add)
    if (Want 'S1') {
        New-TCConfig $Exe $OutDir | Out-Null
        Remove-Fixtures
        $blobs = Get-Blobs $Exe $OutDir 'pa55word' 'Master!23'
        New-AltapFixture -Blobs $blobs | Out-Null
        $src0 = Source-Dump
        $m0 = Get-RegMap $script:TCRoot
        $slots0 = Get-Slots
        $vw0 = Get-Items "$script:TCRoot\Viewers"
        $ed0 = Get-Items "$script:TCRoot\Editors"
        $um0 = Get-Items "$script:TCRoot\User Menu"
        $plug0 = Get-PluginDlls
        $r = Invoke-TC $Exe "[import]`r`ngroups=defaults`r`n" $OutDir 's1'
        $r.Preview | Set-Content -LiteralPath (Join-Path $OutDir 's1_preview.txt') -Encoding UTF8
        $r.Result | Set-Content -LiteralPath (Join-Path $OutDir 's1_result.txt') -Encoding UTF8
        Check 'S1 exits normally' ($r.Exit -eq 0 -and -not $r.Timeout) "exit=$($r.Exit) windows=$($r.Windows -join ';')"
        Check 'S1 applied' ($null -ne $r.Result -and $r.Result -notmatch 'NOT APPLIED' -and $r.Result -match 'Backup of your previous settings') ($r.Result -split "`r`n" | Select-Object -First 3) -join ' / '
        Check 'S1 no consent needed by defaults' ($r.Preview -notmatch '(?m)^  [~-] ') 'no ~ or - line in the preview'
        $m1 = Get-RegMap $script:TCRoot
        $ch = Changed-Values $m0 $m1 (@('Hot Paths\', 'User Menu\', 'Viewers\', 'Alternative Viewers\', 'Editors\', 'Plugins Configuration\FTP\Bookmarks\', 'Plugins Configuration\FTP\Proxy Servers\', 'Plugins\') + $noisePrefixes)
        Check 'S1 SC-010 no existing value changed' ($ch.Count -eq 0) ("changed: " + ($ch -join ', '))
        $slots1 = Get-Slots
        $kept = $true; foreach ($s in $slots0.Keys) { if ($slots1[$s] -ne $slots0[$s]) { $kept = $false } }
        Check 'S1 current hot paths keep their slots' $kept ("before=" + ($slots0.Keys -join ','))
        $paths = @($slots1.Values | ForEach-Object { $_.Split('|')[1] })
        Check 'S1 hot paths added' (($paths -contains 'C:\Projects') -and ($paths -contains 'C:\Windows') -and ($paths -contains '$(SalDir)\plugins') -and ($paths -contains $ZL)) ($paths -join ' ; ')
        # (PowerShell variable names ignore case: never name this one like $CZ)
        $czRows = @($slots1.Values | Where-Object { $_.StartsWith($CZ + '|', [StringComparison]::Ordinal) })
        $want = "$CZ|$ZL|1"
        Check 'S11 non-ASCII hot path name and path exact' ($czRows.Count -eq 1 -and [string]::CompareOrdinal($czRows[0], $want) -eq 0) (($czRows -join ';') + ' codepoints=' + ((($czRows -join '').ToCharArray() | ForEach-Object { [int]$_ }) -join ','))
        $um1 = Get-Items "$script:TCRoot\User Menu"
        $umOk = $true; for ($i = 0; $i -lt $um0.Count; $i++) { if ($um1[$i] -ne $um0[$i]) { $umOk = $false } }
        Check 'S1 user menu: current items first, unchanged' $umOk "before=$($um0.Count) after=$($um1.Count)"
        Check 'S1 user menu: two items appended' ($um1.Count -eq $um0.Count + 2 -and ($um1[-2] -match 'Item Name=&Notepad') -and ($um1[-1] -match 'Item Name=Old tool')) ($um1 | Select-Object -Last 2) -join ' || '
        $vw1 = Get-Items "$script:TCRoot\Viewers"
        $missing = @($vw0 | Where-Object { $vw1 -notcontains $_ })
        Check 'S1 viewers: every current row kept' ($missing.Count -eq 0) ("missing: " + ($missing -join ' || '))
        $pv = TCPluginNumber 'pictview\pictview.spl'
        $jpg = @($vw1 | Where-Object { $_ -match '(^|;)Masks=\*\.jpg(;|$)' -and $_ -match "Type=-$pv(;|$)" })
        Check 'S1 viewers: plugin row re-mapped by DLL (PictView)' ($jpg.Count -ge 1 -and $pv -gt 0) "pictview=Plugins\$pv rows=$($jpg -join ' || ')"
        Check 'S1 viewers: unknown plugin row not imported' (@($vw1 | Where-Object { $_ -match 'Masks=\*\.htm;\*\.html' }).Count -eq @($vw0 | Where-Object { $_ -match 'Masks=\*\.htm;\*\.html' }).Count) 'IE viewer row'
        $log = @($vw1 | Where-Object { $_ -match 'Masks=\*\.log' -and $_ -match 'Command=notepad\.exe' })
        Check 'S1 viewers: external row added' ($log.Count -ge 1) ($log -join ' || ')
        $ed1 = Get-Items "$script:TCRoot\Editors"
        Check 'S1 editors: row added, current kept' (@($ed0 | Where-Object { $ed1 -notcontains $_ }).Count -eq 0 -and @($ed1 | Where-Object { $_ -match 'Masks=\*\.ini' }).Count -ge 1) "before=$($ed0.Count) after=$($ed1.Count)"
        $altap = Find-Bookmark 'Altap'
        $work = Find-Bookmark 'Work'
        $proxy = Find-Proxy 'Office proxy'
        Check 'S1 FTP bookmarks added' ($null -ne $altap -and $null -ne $work) 'Altap, Work'
        Check 'S1 FTP proxy added' ($null -ne $proxy) 'Office proxy'
        if ($null -ne $work -and $null -ne $proxy) {
            $wuid = (Get-ItemProperty $work.PSPath).'Proxy Server UID'
            $puid = (Get-ItemProperty $proxy.PSPath).'Unique ID'
            Check 'S1 FTP bookmark refers to the imported proxy (UID re-mapped)' ($wuid -eq $puid) "bookmark=$wuid proxy=$puid"
            $pw = $work.GetValue('PasswordS', $null)
            Check 'S1 FTP scrambled password usable' ($null -ne $pw -and (Decode $pw) -eq 'pa55word') "len=$(if ($pw) { $pw.Length } else { 0 })"
        }
        Check 'S1 plugin registration unchanged' ((Get-PluginDlls) -eq $plug0) (Get-PluginDlls)
        Check 'S1 SC-002 source unchanged' ((Source-Dump) -eq $src0) 'fixture dump equal'
        $own = $true; foreach ($n in $ownBefore.Keys) { if ((Get-Val 'Configuration' $n) -ne $ownBefore[$n]) { $own = $false } }
        Check 'S1 TC-owned values unchanged' $own (($ownBefore.Keys | ForEach-Object { "$_=$(Get-Val 'Configuration' $_)" }) -join ' ')
        if ($r.Result -match 'Backup of your previous settings: (.+?)\r?\n') { $script:S1Backup = $Matches[1].Trim() }
        Check 'S1 backup file exists' ($script:S1Backup -and (Test-Path -LiteralPath $script:S1Backup)) "$script:S1Backup"
        $script:S1Before = $m0

        # ------------------------------------------------------------ S3 second run adds nothing
        $um1c = $um1.Count; $vw1c = $vw1.Count; $slots1c = $slots1.Count
        $r = Invoke-TC $Exe "[import]`r`ngroups=defaults`r`n" $OutDir 's3'
        $r.Preview | Set-Content -LiteralPath (Join-Path $OutDir 's3_preview.txt') -Encoding UTF8
        Check 'S3 second run: no + line' ($r.Preview -notmatch '(?m)^  \+ ') 'preview has no added item'
        Check 'S3 second run: lists did not grow' ((Get-Items "$script:TCRoot\User Menu").Count -eq $um1c -and (Get-Items "$script:TCRoot\Viewers").Count -eq $vw1c -and (Get-Slots).Count -eq $slots1c) "um=$((Get-Items "$script:TCRoot\User Menu").Count) vw=$((Get-Items "$script:TCRoot\Viewers").Count) hp=$((Get-Slots).Count)"
        $bm = @(Get-ChildItem "$script:TCRoot\Plugins Configuration\FTP\Bookmarks")
        Check 'S3 second run: FTP bookmarks not duplicated' (@($bm | Where-Object { (Get-ItemProperty $_.PSPath).Address -eq 'ftp.work.example' }).Count -eq 1) "bookmarks=$($bm.Count)"

        # ------------------------------------------------------------ S10 backup restores
        if ($script:S1Backup -and (Test-Path -LiteralPath $script:S1Backup)) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $Exe
            $psi.Arguments = "-C `"$script:S1Backup`""
            $psi.UseShellExecute = $false
            $ini = Join-Path $OutDir 's10.ini'
            [IO.File]::WriteAllText($ini, "[import]`r`ngroups=none`r`nsource=none`r`n", (New-Object System.Text.UnicodeEncoding($false, $true)))
            $psi.EnvironmentVariables['TC_CFGIMPORT_AUTORUN'] = $ini
            $psi.EnvironmentVariables['TC_CFGIMPORT_TEST_ROOT'] = 'Software\Tandem Commander Test 245 Empty'
            $p = [System.Diagnostics.Process]::Start($psi)
            $done = $p.WaitForExit(90000)
            if (-not $done) { $w = [Win245]::TopWindows([uint32]$p.Id); try { $p.Kill() } catch {} } else { $w = @() }
            $m10 = Get-RegMap $script:TCRoot
            $diff = Changed-Values $script:S1Before $m10 $noisePrefixes
            $extra = @($m10.Keys | Where-Object { -not $script:S1Before.ContainsKey($_) -and -not $noise.ContainsKey($_) })
            Check 'S10 -C backup restores the pre-import configuration' ($done -and $diff.Count -eq 0 -and $extra.Count -eq 0) ("windows=$($w -join ';') changed=" + ($diff -join ', ') + " extra=" + ($extra -join ', '))
        }
    }

    # ---------------------------------------------------------------- S2 replace / take over
    if (Want 'S2') {
        New-TCConfig $Exe $OutDir | Out-Null
        Remove-Fixtures
        New-AltapFixture | Out-Null
        $src0 = Source-Dump
        $plug0 = Get-PluginDlls
        $mdv = @(Get-Items "$script:TCRoot\Viewers" | Where-Object { $_ -match 'Masks=\*\.md' })
        $groups = 'hotpaths:replace,usermenu:replace,ftp:replace,pluginkeys:replace,viewers,histories,confirmations,panelopts,general,viewer,defaultdirs,plugin:Renamer'
        $r = Invoke-TC $Exe "[import]`r`ngroups=$groups`r`nconsent=1`r`n" $OutDir 's2'
        $r.Preview | Set-Content -LiteralPath (Join-Path $OutDir 's2_preview.txt') -Encoding UTF8
        $r.Result | Set-Content -LiteralPath (Join-Path $OutDir 's2_result.txt') -Encoding UTF8
        Check 'S2 applied' ($r.Exit -eq 0 -and $r.Result -notmatch 'NOT APPLIED') (($r.Result -split "`r`n" | Select-Object -First 2) -join ' / ')
        $slots = Get-Slots
        Check 'S2 hot paths = the source''s slots' ($slots.Count -eq 4 -and $slots[1] -eq 'Projects|C:\Projects|1' -and $slots[2] -eq 'C:\Windows|C:\Windows|1' -and $slots[3] -eq 'Salamander|$(SalDir)\plugins|0') (($slots.Keys | Sort-Object | ForEach-Object { "$_=$($slots[$_])" }) -join ' ; ')
        $um = Get-Items "$script:TCRoot\User Menu"
        Check 'S2 user menu = the source''s' ($um.Count -eq 2) ($um -join ' || ')
        $bm = @(Get-ChildItem "$script:TCRoot\Plugins Configuration\FTP\Bookmarks" | ForEach-Object { (Get-ItemProperty $_.PSPath).Name })
        Check 'S2 FTP bookmarks = the source''s' ($bm.Count -eq 2 -and $bm -contains 'Altap' -and $bm -contains 'Work') ($bm -join ',')
        Check 'S2 confirmations taken over' ((Get-Val 'Configuration\Confirmation' 'File Overwrite') -eq 0 -and (Get-Val 'Configuration\Confirmation' 'Close Find') -eq 0) 'File Overwrite=0 Close Find=0'
        Check 'S2 panel options taken over' ((Get-Val 'Configuration' 'Single Click') -eq 1 -and (Get-Val 'Configuration' 'Sort Dirs By Ext') -eq 1) 'Single Click=1 Sort Dirs By Ext=1'
        Check 'S2 out-of-range value not taken (Thumbnail Size 5000)' ((Get-Val 'Configuration' 'Thumbnail Size') -ne 5000) "Thumbnail Size=$(Get-Val 'Configuration' 'Thumbnail Size')"
        Check 'S2 general option taken over (Use Recycle Bin 2)' ((Get-Val 'Configuration' 'Use Recycle Bin') -eq 2) "$(Get-Val 'Configuration' 'Use Recycle Bin')"
        $own = $true; foreach ($n in $ownBefore.Keys) { if ((Get-Val 'Configuration' $n) -ne $ownBefore[$n]) { $own = $false } }
        Check 'S2 TC-owned values unchanged (theme, tabs, language, quick search, shell)' $own (($ownBefore.Keys | ForEach-Object { "$_=$(Get-Val 'Configuration' $_)" }) -join ' ')
        $hist = Get-Item "$script:TCRoot\Configuration\ChangeDir History" -ErrorAction SilentlyContinue
        $hv = if ($hist) { @($hist.GetValueNames() | ForEach-Object { $hist.GetValue($_) }) } else { @() }
        Check 'S2 history imported, password removed' (($hv -contains 'C:\Old\History') -and (@($hv | Where-Object { $_ -match 'secret' }).Count -eq 0) -and ($hv -contains 'ftp://joe@host/dir')) ($hv -join ' ; ')
        Check 'S2 plugin settings taken over (Renamer)' ((Get-Val 'Plugins Configuration\Renamer' 'Last Used Options') -eq 'x') "Last Used Options=$(Get-Val 'Plugins Configuration\Renamer' 'Last Used Options')"
        Check 'S2 plugin registration unchanged' ((Get-PluginDlls) -eq $plug0) ''
        $mdv2 = @(Get-Items "$script:TCRoot\Viewers" | Where-Object { $_ -match 'Masks=\*\.md' })
        Check 'S2 TC-only plugin association kept (Markdown viewer)' ($mdv.Count -eq $mdv2.Count -and $mdv.Count -ge 1) "md rows before=$($mdv.Count) after=$($mdv2.Count)"
        Check 'S2 SC-002 source unchanged' ((Source-Dump) -eq $src0) ''
    }

    # ---------------------------------------------------------------- S5 no consent
    if (Want 'S5') {
        New-TCConfig $Exe $OutDir | Out-Null
        Remove-Fixtures
        New-AltapFixture | Out-Null
        $m0 = Get-RegMap $script:TCRoot
        $r = Invoke-TC $Exe "[import]`r`ngroups=hotpaths:replace,confirmations`r`n" $OutDir 's5'
        Check 'S5 replace without consent: not applied' ($r.Result -match 'NOT APPLIED: consent needed') ($r.Result)
        $m1 = Get-RegMap $script:TCRoot
        $ch = Changed-Values $m0 $m1 $noisePrefixes
        $extra = @($m1.Keys | Where-Object { -not $m0.ContainsKey($_) -and -not $noise.ContainsKey($_) })
        Check 'S5 nothing changed' ($ch.Count -eq 0 -and $extra.Count -eq 0) ("changed=" + ($ch -join ', ') + " extra=" + ($extra -join ', '))
    }

    # ---------------------------------------------------------------- S6 versions
    if (Want 'S6') {
        New-TCConfig $Exe $OutDir | Out-Null
        Remove-Fixtures
        New-AltapFixture -Name 'Altap Salamander 2.52' -Version 46 | Out-Null
        Set-RegTree (Join-Path $script:FixPS 'Altap Salamander 2.52') @{ 'Viewers\1' = @{ 'Masks' = '*.LOG'; 'Type' = 0; 'Command' = 'notepad.exe' } }
        New-AltapFixture -Name 'Altap Salamander 2.51' -Version 43 | Out-Null
        Set-RegTree (Join-Path $script:FixPS 'Altap Salamander 2.51') @{ 'Viewers\1' = @{ 'Masks' = '*.LOG'; 'Type' = 0; 'Command' = 'notepad.exe' } }
        New-AltapFixture -Name 'Servant Salamander 2.0' -Version 38 | Out-Null
        New-AltapFixture -Name 'Future Salamander' -Version 107 | Out-Null
        $r = Invoke-TC $Exe "[import]`r`nsource=Servant Salamander 2.0`r`ngroups=defaults`r`n" $OutDir 's6old'
        Check 'S6 version 38 refused' ($null -ne $r.Error -and $r.Error -match 'Servant Salamander 2\.0\|38\|1') (($r.Error -split "`r`n") -join ' / ')
        Check 'S6 version 107 listed as too new' ($null -ne $r.Error -and $r.Error -match 'Future Salamander\|107\|2') ''
        $r = Invoke-TC $Exe "[import]`r`nsource=Altap Salamander 2.52`r`ngroups=hotpaths,viewers`r`n" $OutDir 's6'
        $paths = @((Get-Slots).Values | ForEach-Object { $_.Split('|')[1] })
        Check 'S6 < 47: $ doubled in hot paths' ($paths -contains '$$(SalDir)\plugins') ($paths -join ' ; ')
        New-TCConfig $Exe $OutDir | Out-Null
        $r = Invoke-TC $Exe "[import]`r`nsource=Altap Salamander 2.51`r`ngroups=viewers`r`n" $OutDir 's6b'
        $vw = Get-Items "$script:TCRoot\Viewers"
        Check 'S6 < 44: masks lower-cased' (@($vw | Where-Object { $_ -match 'Masks=\*\.log;' -or $_ -match 'Masks=\*\.log$' }).Count -ge 1 -and @($vw | Where-Object { $_ -cmatch 'Masks=\*\.LOG' }).Count -eq 0) ''
    }

    # ---------------------------------------------------------------- S7 passwords
    if (Want 'S7') {
        Remove-Fixtures
        $blobs = Get-Blobs $Exe $OutDir 'pa55word' 'Master!23'
        $tcBlobs = Get-Blobs $Exe $OutDir 'unused' 'TcMaster1'
        $cases = @(
            @{ Tag = 's7a'; Ini = "pwdpolicy=2`r`nmasterpassword=Master!23`r`nweakconsent=1"; TCMaster = $false; Expect = 'S' },
            @{ Tag = 's7b'; Ini = "pwdpolicy=2`r`nmasterpassword=WRONG`r`nweakconsent=1"; TCMaster = $false; Expect = 'none' },
            @{ Tag = 's7c'; Ini = "pwdpolicy=2`r`nmasterpassword=Master!23`r`nweakconsent=0"; TCMaster = $false; Expect = 'none' },
            @{ Tag = 's7d'; Ini = "pwdpolicy=2`r`nmasterpassword=Master!23`r`ntcmasterpassword=TcMaster1"; TCMaster = $true; Expect = 'E' },
            @{ Tag = 's7e'; Ini = "pwdpolicy=0"; TCMaster = $false; Expect = 'none' }
        )
        foreach ($c in $cases) {
            New-TCConfig $Exe $OutDir | Out-Null
            if ($c.TCMaster) {
                Set-RegTree $script:TCRoot @{ 'Password Manager' = @{ 'Use Master Password' = 1; 'Master Password Verifier' = $tcBlobs['V'] } }
            }
            $pm0 = (Get-RegDump "$script:TCRoot\Password Manager") -join "`n"
            Remove-Fixtures
            New-AltapFixture -Blobs $blobs -UseMaster $true | Out-Null
            $r = Invoke-TC $Exe "[import]`r`ngroups=ftp`r`n$($c.Ini)`r`n" $OutDir $c.Tag
            $r.Preview | Set-Content -LiteralPath (Join-Path $OutDir "$($c.Tag)_preview.txt") -Encoding UTF8
            $work = Find-Bookmark 'Work'
            $e = if ($work) { $work.GetValue('PasswordE', $null) } else { $null }
            $s = if ($work) { $work.GetValue('PasswordS', $null) } else { $null }
            switch ($c.Expect) {
                'S' { $ok = ($null -ne $s -and $null -eq $e -and (Decode $s) -eq 'pa55word') }
                'E' { $ok = ($null -ne $e -and $null -eq $s -and (Decode $e 'TcMaster1') -eq 'pa55word') }
                default { $ok = ($null -ne $work -and $null -eq $e -and $null -eq $s) }
            }
            Check "S7 $($c.Tag) password expected=$($c.Expect)" $ok ("diag=$($r.Diag) exit=$($r.Exit) timeout=$($r.Timeout) windows=$($r.Windows -join ';') bookmark=" + [bool]$work + " E=" + [bool]$e + " S=" + [bool]$s + " result=" + (($r.Result -split "`r`n" | Select-String 'Work') -join ' '))
            $pm1 = (Get-RegDump "$script:TCRoot\Password Manager") -join "`n"
            Check "S7 $($c.Tag) SC-009 TC master password unchanged" ($pm0 -eq $pm1) ''
        }
    }

    # ---------------------------------------------------------------- S8 plugin shortcuts
    if (Want 'S8') {
        New-TCConfig $Exe $OutDir | Out-Null
        Remove-Fixtures
        $root = New-AltapFixture
        Set-RegTree $root @{
            'Plugins\2\Menu\2' = @{ 'Name' = 'Edit bookmarks'; 'ID' = 7; 'State' = 0; 'HotKey' = (0x10000 -bor 0x0642) }   # Ctrl+Alt+B: free
            'Plugins\2\Menu\3' = @{ 'Name' = 'Logs'; 'ID' = 5; 'State' = 0; 'HotKey' = (0x10000 -bor 0x0354) }             # Ctrl+Shift+T: a TC command
        }
        $ftp = TCPluginNumber 'ftp\ftp.spl'
        $r = Invoke-TC $Exe "[import]`r`ngroups=pluginkeys`r`n" $OutDir 's8'
        $r.Preview | Set-Content -LiteralPath (Join-Path $OutDir 's8_preview.txt') -Encoding UTF8
        $keys = @{}
        foreach ($k in Get-ChildItem "$script:TCRoot\Plugins\$ftp\Menu") { $v = Get-ItemProperty $k.PSPath; if ($v.ID -ne $null) { $keys[[int]$v.ID] = $v.HotKey } }
        Check 'S8 free shortcut assigned (user-assigned bit)' ($keys[7] -eq (0x10000 -bor 0x0642)) ("id7=" + ('{0:x}' -f $keys[7]))
        Check 'S8 TC command shortcut refused' ($keys[5] -ne (0x10000 -bor 0x0354) -and $r.Preview -match 'belongs to a command of Tandem Commander') ("id5=" + ('{0:x}' -f $keys[5]))
        Check 'S8 Add keeps the current default shortcut' ($keys[1] -eq 0x0346 -and $r.Preview -match 'already has a shortcut') ("id1=" + ('{0:x}' -f $keys[1]))
    }

    # ---------------------------------------------------------------- S9 another instance
    if (Want 'S9') {
        New-TCConfig $Exe $OutDir | Out-Null
        Remove-Fixtures
        New-AltapFixture | Out-Null
        $m0 = Get-RegMap $script:TCRoot
        $first = Start-Process -FilePath $Exe -PassThru
        Start-Sleep -Seconds 6
        $r = Invoke-TC $Exe "[import]`r`ngroups=defaults`r`n" $OutDir 's9'
        try { $first.Kill() } catch {}
        $first.WaitForExit(10000) | Out-Null
        Check 'S9 refused while another instance runs' ($r.Result -match 'NOT APPLIED: Close the other Tandem Commander') ($r.Result)
    }
}
finally {
    Remove-Fixtures
    Get-Process tandemcommander -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Kill() } catch {} }
    Restore-TC $backup $existed
    $after0 = Get-RegDump $script:TCPS
    $same = (($before0 -join "`n") -eq ($after0 -join "`n"))
    Check 'registry restored' $same ''
    $script:Results | Set-Content -LiteralPath $OutFile -Encoding UTF8
    Write-Output "FAILED: $script:Fails"
}
