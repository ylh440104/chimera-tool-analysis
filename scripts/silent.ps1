param([string]$Exe, [string]$Tag)
$ErrorActionPreference='Continue'
$switches=@('/S','/s','/silent','/SILENT','/verysilent','/q','/quiet','/extract')
foreach($sw in $switches){
  Write-Host "=== $Tag $sw ==="
  $name = $sw.TrimStart('/')
  try {
    $proc = Start-Process -FilePath $Exe -ArgumentList $sw -PassThru -WorkingDirectory (Get-Location).Path -RedirectStandardOutput "silent-$Tag-$name.log" -RedirectStandardError "silent-$Tag-$name.err"
    $ok = $proc.WaitForExit(25000)
    if($ok){ Write-Host "  exit=$($proc.ExitCode)" } else { Write-Host '  timeout, kill'; try{$proc.Kill()}catch{} }
  } catch { Write-Host "  err $_" }
  Start-Sleep 4
  Get-ChildItem $env:TEMP -Directory -Filter '_ir_sf*' -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  dir $($_.FullName)"; Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Select-Object FullName,Length | Format-Table -AutoSize | Out-String | Write-Host }
}
