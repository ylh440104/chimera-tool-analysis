param([string]$Sample = 'ChimeraTool_Authenticator_Driver.exe', [string]$Irsetup = 'irsetup_upx.exe')
$ErrorActionPreference='Continue'
$work = Join-Path (Get-Location).Path 'irwork'
New-Item -ItemType Directory -Force $work | Out-Null
Copy-Item $Sample $work -Force
Copy-Item $Irsetup $work -Force
Copy-Item 'lua5.1.dll' $work -Force -ErrorAction SilentlyContinue
Push-Location $work
Write-Host "=== work dir: $work ==="
Get-ChildItem | Select-Object Name,Length | Format-Table -AutoSize | Out-String | Write-Host

# start irsetup; it should parse its own suffix/overlay
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = (Resolve-Path $Irsetup).Path
$psi.WorkingDirectory = $work
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()
Write-Host "started irsetup pid=$($p.Id)"
Start-Sleep 25

# dump while running
if(-not $p.HasExited){
  Write-Host '=== dumping irsetup ==='
  & "$PWD\..\pd\procdump64.exe" -accepteula -ma $p.Id "irsetup-$($p.Id).dmp" 2>&1 | Out-String | Write-Host
  Write-Host "dmp: $(Test-Path "irsetup-$($p.Id).dmp")"
  try { $mods = $p.Modules | ForEach-Object { "{0}|{1}" -f $_.ModuleName, $_.FileName }; $mods | Out-File irsetup-modules.txt; Write-Host "modules=$($mods.Count)" } catch { Write-Host "mod err $_" }
} else {
  Write-Host "irsetup exited early code=$($p.ExitCode)"
  "exited $($p.ExitCode)" | Out-File irsetup-exit.txt
}

# also try the real sample overlay scenario: rename sample to irsetup and run it
Write-Host '=== second run: sample-as-irsetup ==='
Copy-Item $Sample 'irsetup2.exe' -Force
try { & "$PWD\..\pd\procdump64.exe" -accepteula -ma $p.Id "irsetup2-$($p.Id).dmp" 2>&1 | Out-Null } catch {}

Start-Sleep 8
if(-not $p.HasExited){ try{$p.Kill()}catch{} }

# list any newly created files inside work
Write-Host '=== work tree after ==='
Get-ChildItem $work -Recurse -File | Select-Object FullName,Length | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
Pop-Location

# dump irsetup's module listing for later overlay carving
Write-Host '=== irsetup string check ==='
if(Test-Path "$work\irsetup_upx.exe"){
  $bytes=[System.IO.File]::ReadAllBytes("$work\irsetup_upx.exe")
  Write-Host "irsetup_upx size=$($bytes.Length)"
}
