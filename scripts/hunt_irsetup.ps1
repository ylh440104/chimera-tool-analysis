$ErrorActionPreference='Continue'
# launch the real Setup Factory installer, then hunt for its irsetup child and dump it
$exe = 'ChimeraTool_Authenticator_Driver.exe'
$out = Join-Path (Get-Location).Path 'hunt'
New-Item -ItemType Directory -Force $out | Out-Null

# watcher: dump any process named irsetup* as soon as it appears
$watcher = Start-Job -ScriptBlock {
  param($pdPath, $outDir)
  $done = @{}
  $end = (Get-Date).AddMinutes(14)
  while((Get-Date) -lt $end){
    foreach($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'irsetup|suf_|setup|authdrv|Chimera' })){
      if(-not $done.ContainsKey($proc.Id)){
        $done[$proc.Id]=1
        $dmp = Join-Path $outDir ("$($proc.ProcessName)-$($proc.Id).dmp")
        try {
          & $pdPath -accepteula -ma $proc.Id $dmp 2>&1 | Out-File -Append (Join-Path $outDir 'pd.log')
          if((Test-Path $dmp) -and (Get-Item $dmp).Length -gt 0){
            Write-Output "DUMPED $($proc.ProcessName) $($proc.Id) -> $dmp"
            try { $proc.Modules | ForEach-Object { "{0}|{1}|{2}" -f $proc.ProcessName,$_.ModuleName,$_.FileName } | Out-File -Append (Join-Path $outDir 'modules.txt') } catch {}
          }
        } catch { Write-Output "err $($proc.ProcessName): $_" }
      }
    }
    Start-Sleep -Milliseconds 600
  }
} -ArgumentList (Resolve-Path 'pd\procdump64.exe').Path, $out

Write-Host "watcher job=$($watcher.Id)"
$p = Start-Process -FilePath $exe -PassThru -WorkingDirectory (Get-Location).Path
Write-Host "installer pid=$($p.Id)"

# also try driving the Install button via WM messages
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class M {
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  public static string T(IntPtr h){ var s=new StringBuilder(512); GetWindowText(h,s,512); return s.ToString(); }
  public static string C(IntPtr h){ var s=new StringBuilder(256); GetClassName(h,s,256); return s.ToString(); }
}
"@
Start-Sleep 22
# click at multiple probable Install-button positions via WM_LBUTTONDOWN/UP (client coords)
$hwnds=@()
$script:pid2=$p.Id
[M]::EnumWindows({ param($h,$l) $q=0; [M]::GetWindowThreadProcessId($h,[ref]$q)|Out-Null; if($q -eq $script:pid2){ $t=[M]::T($h); if($t){ [void]$script:hwnds.Add($h); Write-Output "win $h [$t]" } }; return $true },[IntPtr]::Zero)|Out-Null
foreach($h in $script:hwnds){
  $r=New-Object M+RECT
  if([M]::GetWindowRect($h,[ref]$r)){
    $w=$r.R-$r.L; $ht=$r.B-$r.T
    Write-Host "hwnd=$h size=${w}x${ht}"
    # Install driver button typically near bottom-right / bottom-center of the wizard
    foreach($fx in @(0.72,0.80,0.86,0.90)){
      foreach($fy in @(0.86,0.90,0.94)){
        $cx=[int]($w*$fx); $cy=[int]($ht*$fy)
        $lp=[IntPtr](($cy -shl 16) -bor $cx)
        [M]::PostMessage($h,0x0200,[IntPtr]::Zero,$lp)|Out-Null   # WM_MOUSEMOVE
        [M]::PostMessage($h,0x0201,[IntPtr]1,$lp)|Out-Null       # WM_LBUTTONDOWN
        Start-Sleep -Milliseconds 120
        [M]::PostMessage($h,0x0202,[IntPtr]::Zero,$lp)|Out-Null  # WM_LBUTTONUP
        Start-Sleep -Milliseconds 400
      }
    }
  }
}
Write-Host 'clicked; waiting for child processes'
Start-Sleep 90

Write-Host '=== procs now ==='
Get-Process | Where-Object { $_.ProcessName -match 'irsetup|suf_|setup|authdrv|Chimera' } | Format-Table Id,ProcessName,MainWindowTitle -AutoSize | Out-String | Write-Host

Stop-Job $watcher -ErrorAction SilentlyContinue
Receive-Job $watcher -ErrorAction SilentlyContinue | Out-String | Write-Host
Remove-Job $watcher -Force -ErrorAction SilentlyContinue

if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }

Write-Host '=== hunt dir ==='
Get-ChildItem $out -Recurse -File | Select-Object FullName,Length | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
Write-Host '=== temp ir_sf ==='
Get-ChildItem $env:TEMP -Directory -Filter '_ir_sf*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName; Get-ChildItem $_.FullName -Recurse -File | Select-Object Name,Length | Format-Table -AutoSize | Out-String | Write-Host }
