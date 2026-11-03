$ErrorActionPreference='Continue'
$out = Join-Path (Get-Location).Path 'snatched'
New-Item -ItemType Directory -Force $out | Out-Null
$seen = @{}
$end = (Get-Date).AddMinutes(38)
while((Get-Date) -lt $end){
  foreach($d in (Get-ChildItem $env:TEMP -Directory -Filter '_ir_sf*' -ErrorAction SilentlyContinue)){
    foreach($f in (Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue)){
      if(-not $seen.ContainsKey($f.FullName)){
        $seen[$f.FullName]=1
        $dst = Join-Path $out ("{0}_{1}" -f $f.Length, $f.Name)
        try { Copy-Item $f.FullName $dst -Force -ErrorAction Stop; Write-Host "SNATCH $($f.FullName) -> $dst" } catch {}
      }
    }
  }
  Start-Sleep -Milliseconds 350
}
