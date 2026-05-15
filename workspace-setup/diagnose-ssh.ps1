# Diagnostic v3: show ~/.ssh/config, and test the SFTP subsystem the way sshfs uses it.
# Launched by DIAGNOSE-SSH.bat. Writes diagnose-result.txt next to this script.
$ErrorActionPreference = 'Continue'

$ResultFile = Join-Path $PSScriptRoot 'diagnose-result.txt'
$key        = "$HOME\.ssh\google_compute_engine"
$sshConfig  = Join-Path $HOME '.ssh\config'
$Target     = 'omar_elzanaty_almobarmg@34.79.246.143'

$log = New-Object System.Collections.Generic.List[string]
function Say($m) { Write-Host $m; $log.Add([string]$m) }
function Save() { Set-Content -Path $ResultFile -Value $log -Encoding UTF8 }

Say "=== SSH SFTP-subsystem diagnostic v3 ==="
Say ("time: " + (Get-Date))

Say ""
Say "--- current ~/.ssh/config ---"
if (Test-Path $sshConfig) {
    Get-Content $sshConfig | ForEach-Object { Say ("  | " + $_) }
} else {
    Say "  (no config file)"
}

# TEST A: regular command (known-good baseline)
Say ""
Say "--- TEST A: ssh 'echo' (baseline) ---"
$ta = Join-Path $env:TEMP 'fyt-a.txt'
if (Test-Path $ta) { Remove-Item $ta -Force -EA SilentlyContinue }
& ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -i $key $Target "echo BASELINE_OK" 2>&1 |
    Out-File -FilePath $ta -Encoding ascii
if (Test-Path $ta) { Get-Content $ta | ForEach-Object { Say ("  " + $_) } }

# TEST B: SFTP subsystem, verbose - exactly what sshfs requests
Say ""
Say "--- TEST B: ssh -s sftp (what sshfs does), verbose, ~10s ---"
$tb  = Join-Path $env:TEMP 'fyt-b-err.txt'
$tbo = Join-Path $env:TEMP 'fyt-b-out.txt'
if (Test-Path $tb)  { Remove-Item $tb  -Force -EA SilentlyContinue }
if (Test-Path $tbo) { Remove-Item $tbo -Force -EA SilentlyContinue }
$a = @('-vv','-x','-a','-o','ClearAllForwardings=yes','-o','BatchMode=yes','-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=/dev/null','-i',$key,$Target,'-s','sftp')
$p = Start-Process -FilePath 'ssh' -ArgumentList $a -WindowStyle Hidden -RedirectStandardError $tb -RedirectStandardOutput $tbo -PassThru
Start-Sleep -Seconds 10
if ($p -and -not $p.HasExited) { try { $p.Kill() } catch {} }
Start-Sleep -Seconds 1
if ((Test-Path $tb) -and ((Get-Item $tb).Length -gt 0)) {
    Get-Content $tb | ForEach-Object { Say ("  " + $_) }
} else {
    Say "  (stderr empty)"
}

# TEST C: try the 'sftp' client directly
Say ""
Say "--- TEST C: sftp client (batch 'pwd'), verbose tail ---"
$tc = Join-Path $env:TEMP 'fyt-c.txt'
if (Test-Path $tc) { Remove-Item $tc -Force -EA SilentlyContinue }
"pwd`nexit`n" | Out-File -FilePath (Join-Path $env:TEMP 'fyt-sftp-batch.txt') -Encoding ascii
& sftp -v -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -i $key -b (Join-Path $env:TEMP 'fyt-sftp-batch.txt') $Target 2>&1 |
    Out-File -FilePath $tc -Encoding ascii
if (Test-Path $tc) { Get-Content $tc | Select-Object -Last 30 | ForEach-Object { Say ("  " + $_) } }

Save
