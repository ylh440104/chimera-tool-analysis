$ErrorActionPreference='Continue'
# carve PE/archive candidates out of an unpacked irsetup binary and its dumps
$targets = @()
$targets += (Get-ChildItem . -Filter '*.dmp' -ErrorAction SilentlyContinue)
$targets += (Get-ChildItem . -Filter 'irsetup*.exe' -ErrorAction SilentlyContinue)
New-Item -ItemType Directory -Force carved | Out-Null
foreach($t in $targets){
  Write-Host "=== carve $($t.Name) $([math]::Round($t.Length/1MB,1))MB ==="
  $bytes=[System.IO.File]::ReadAllBytes($t.FullName)
  $found=0
  for($i=0; $i -lt $bytes.Length-0x40; $i++){
    if($bytes[$i] -eq 0x4D -and $bytes[$i+1] -eq 0x5A){
      $lf=[BitConverter]::ToInt32($bytes,$i+0x3c)
      if($lf -gt 0 -and ($i+$lf+4) -lt $bytes.Length){
        if($bytes[$i+$lf] -eq 0x50 -and $bytes[$i+$lf+1] -eq 0x45 -and $bytes[$i+$lf+2] -eq 0 -and $bytes[$i+$lf+3] -eq 0){
          $mach=[BitConverter]::ToUInt16($bytes,$i+$lf+4)
          $nsec=[BitConverter]::ToUInt16($bytes,$i+$lf+6)
          $szopt=[BitConverter]::ToUInt16($bytes,$i+$lf+20)
          $chars=[BitConverter]::ToUInt16($bytes,$i+$lf+22)
          if($nsec -gt 0 -and $nsec -lt 20 -and $szopt -gt 0){
            $soff=$i+$lf+24+$szopt
            $maxend=$i
            $ok=$true
            for($k=0;$k -lt $nsec;$k++){
              $e=$soff+$k*40
              if($e+40 -gt $bytes.Length){ $ok=$false; break }
              $rs=[BitConverter]::ToInt32($bytes,$e+16)
              $ra=[BitConverter]::ToInt32($bytes,$e+20)
              if($ra -gt 0 -and $rs -gt 0){ $end=$i+$ra+$rs; if($end -gt $maxend){ $maxend=$end } }
            }
            if($ok -and $maxend -gt $i+0x400 -and $maxend -le $bytes.Length){
              $isDll = ($chars -band 0x2000) -ne 0
              $isSys = ($chars -band 0x1000) -ne 0
              $sub = 0
              try { $sub=[BitConverter]::ToUInt16($bytes,$i+$lf+24+68) } catch {}
              $name = "carved_{0}_{1}.bin" -f $i, $(if($isDll){'dll'}elseif($isSys){'sys'}else{'exe'})
              [System.IO.File]::WriteAllBytes((Join-Path 'carved' $name), $bytes[$i..($maxend-1)])
              Write-Host "  PE at 0x$('{0:X}' -f $i) machine=0x$('{0:X}' -f $mach) nsec=$nsec dll=$isDll sys=$isSys subsystem=$sub size=$($maxend-$i) -> $name"
              $found++
              if($found -gt 40){ break }
            }
          }
        }
      }
    }
  }
  Write-Host "  carved=$found"
}
Get-ChildItem carved -ErrorAction SilentlyContinue | Select-Object Name,Length | Format-Table -AutoSize | Out-String | Write-Host
# identify each carved file
Get-ChildItem carved -File -ErrorAction SilentlyContinue | ForEach-Object {
  $b=[System.IO.File]::ReadAllBytes($_.FullName)
  $s=[System.Text.Encoding]::ASCII.GetString($b)
  $hits=@()
  foreach($m in @('InstallDriver','SQLInstallDriverEx','CreateServiceA','\SystemRoot\','System32\drivers','.sys','Chimera','HASP','Sentinel')){ if($s.Contains($m)){ $hits += $m } }
  if($hits.Count -gt 0){ Write-Host "$($_.Name): $($hits -join ',')" }
}
