Add-Type -AssemblyName System.Windows.Forms
$n = 0
while ($true) {
  $n++
  $x = 300 + ($n % 40) * 30
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, (300 + ($n % 17) * 20))
  Start-Sleep -Seconds 45
}
