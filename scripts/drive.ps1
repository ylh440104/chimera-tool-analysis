param([string]$Exe, [string]$Tag, [int]$Rounds = 7)
$ErrorActionPreference='Continue'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class W {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,int x,int y,int d,IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, IntPtr e);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  public static string T(IntPtr h){ var s=new StringBuilder(512); GetWindowText(h,s,512); return s.ToString(); }
}
"@
function Shot($f){ $b=New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width,[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height); $g=[System.Drawing.Graphics]::FromImage($b); $g.CopyFromScreen(0,0,0,0,$b.Size); $b.Save($f); $g.Dispose(); $b.Dispose() }
function Grab($h){ $r=New-Object W+RECT; if(-not [W]::GetWindowRect($h,[ref]$r)){ return $null }; $w=$r.R-$r.L; $ht=$r.B-$r.T; if($w -le 0 -or $ht -le 0){ return $null }; $bmp=New-Object System.Drawing.Bitmap($w,$ht); $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L,$r.T,0,0,$bmp.Size); $g.Dispose(); return $bmp }
function Sig($bmp){ if($null -eq $bmp){ return '' }; $ms=New-Object System.IO.MemoryStream; $bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Bmp); $by=$ms.ToArray(); $ms.Dispose(); $sha=[System.Security.Cryptography.SHA256]::Create(); $hh=$sha.ComputeHash($by); return [BitConverter]::ToString($hh).Replace('-','').Substring(0,16) }
function Click($h,$px,$py){ $r=New-Object W+RECT; if(-not [W]::GetWindowRect($h,[ref]$r)){ return }; $w=$r.R-$r.L; $ht=$r.B-$r.T; $x=$r.L+[int]($w*$px); $y=$r.T+[int]($ht*$py); [W]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -Milliseconds 160; [W]::mouse_event(2,0,0,0,[IntPtr]::Zero); Start-Sleep -Milliseconds 80; [W]::mouse_event(4,0,0,0,[IntPtr]::Zero); Write-Host "   click $px,$py -> $x,$y" }
function K($vk){ [W]::keybd_event($vk,0,0,[IntPtr]::Zero); Start-Sleep -Milliseconds 60; [W]::keybd_event($vk,0,2,[IntPtr]::Zero) }
function FindWin($procId){ $script:acc=New-Object System.Collections.ArrayList; $script:p2=$procId; [W]::EnumWindows({ param($h,$l) $q=0; [W]::GetWindowThreadProcessId($h,[ref]$q)|Out-Null; if($q -eq $script:p2 -and [W]::IsWindowVisible($h)){ $t=[W]::T($h); if($t -and $t.Length -gt 2){ [void]$script:acc.Add($h) } }; return $true },[IntPtr]::Zero)|Out-Null; if($script:acc.Count -gt 0){ return $script:acc[0] }; return [IntPtr]::Zero }

Write-Host "=== launching $Exe ==="
$p = Start-Process -FilePath $Exe -PassThru -WorkingDirectory (Get-Location).Path
Start-Sleep 20
$hwnd = FindWin $p.Id
if($hwnd -eq [IntPtr]::Zero){ $hwnd = $p.MainWindowHandle }
Write-Host "hwnd=$hwnd title=$([W]::T($hwnd))"
if($hwnd -ne [IntPtr]::Zero){ [W]::ShowWindow($hwnd,9)|Out-Null }
Start-Sleep 2
$last = Sig (Grab $hwnd)
Write-Host "sig0=$last"
$xs=@(0.35,0.50,0.62,0.72,0.80,0.87,0.93)
$ys=@(0.72,0.80,0.86,0.91,0.95,0.975)
for($r=1; $r -le $Rounds; $r++){
  Shot "$Tag-r$r.png"
  $hwnd = FindWin $p.Id
  if($hwnd -eq [IntPtr]::Zero){ Write-Host "r$r window gone"; break }
  Write-Host "r$r hwnd=$hwnd title=$([W]::T($hwnd))"
  [W]::SetForegroundWindow($hwnd)|Out-Null
  Start-Sleep -Milliseconds 300
  foreach($i in 1..8){ K 0x22 }
  $changed=$false
  foreach($py in $ys){
    foreach($px in $xs){
      Click $hwnd $px $py
      Start-Sleep -Milliseconds 1000
      $h2 = FindWin $p.Id
      if($h2 -ne [IntPtr]::Zero){ $hwnd=$h2 }
      $s2 = Sig (Grab $hwnd)
      if($s2 -ne $last -and $s2 -ne ''){
        Write-Host "   CHANGED $px,$py ($last -> $s2)"
        $last=$s2; $changed=$true
        Shot "$Tag-hit-r$r-$([int]($py*1000)).png"
        break
      }
    }
    if($changed){ break }
  }
  if(-not $changed){
    Write-Host "r$r no change; KB accept"
    [W]::SetForegroundWindow($hwnd)|Out-Null
    K 0x09; Start-Sleep -Milliseconds 250; K 0x0D; Start-Sleep 2
    $s3=Sig (Grab $hwnd)
    if($s3 -ne $last -and $s3 -ne ''){ Write-Host "   KB changed ($last -> $s3)"; $last=$s3 }
  }
  Start-Sleep 3
}
Shot "$Tag-final.png"
Write-Host '=== procs ==='
Get-Process | Where-Object { $_.ProcessName -match 'chimera|setup|install|suf_|irsetup|auth|dpinst|devcon|pnputil' } | Format-Table Id,ProcessName,MainWindowTitle -AutoSize | Out-String | Write-Host
Write-Host '=== services ==='
Get-Service | Where-Object { $_.Name -match 'chimera|auth|dongle|hasp|sentinel|suf|elg' } | Format-Table Name,DisplayName,Status,PathName -AutoSize | Out-String | Write-Host
Write-Host '=== recent sys ==='
Get-ChildItem 'C:\Windows\System32\drivers' -Filter *.sys -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-25) } | Format-Table Name,Length,LastWriteTime -AutoSize | Out-String | Write-Host
Write-Host '=== recent inf ==='
Get-ChildItem 'C:\Windows\INF' -Filter *.inf -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-25) } | Format-Table Name,Length,LastWriteTime -AutoSize | Out-String | Write-Host
Write-Host '=== ir_sf temp ==='
Get-ChildItem $env:TEMP -Directory -Filter '_ir_sf*' -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Select-Object FullName,Length } | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
Write-Host '=== chimera dirs ==='
Get-ChildItem 'C:\Program Files','C:\Program Files (x86)',$env:ProgramData,$env:LOCALAPPDATA -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'chimera|euro' } | Select-Object FullName | Out-String | Write-Host
if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
