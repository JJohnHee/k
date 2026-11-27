# keepawake2.ps1 - anti idle-shutdown: SetThreadExecutionState continuous + mouse wiggle
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SU2 {
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint f);
}
"@
[SU2]::SetThreadExecutionState(0x80000003) | Out-Null
$last = Get-Date
while ($true) {
    try {
        $p = [System.Windows.Forms.Cursor]::Position
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(($p.X + 1), $p.Y)
        Start-Sleep -Milliseconds 200
        [System.Windows.Forms.Cursor]::Position = $p
    } catch {}
    if (((Get-Date) - $last).TotalSeconds -ge 600) {
        "[$(Get-Date -Format 'HH:mm:ss')] alive" | Out-File C:\keepawake.txt -Append
        $last = Get-Date
    }
    [SU2]::SetThreadExecutionState(0x80000003) | Out-Null
    Start-Sleep -Seconds 25
}
