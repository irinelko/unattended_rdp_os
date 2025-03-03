# ===================================================
# Windows RDP Troubleshooter & Fixer for KVM VMs
# Automates enabling RDP, firewall settings, registry fixes,
# and system repair in case of broken RDP.
# ===================================================
Write-Host "Starting RDP Fix Script..." -ForegroundColor Cyan

# Ensure script is running as Administrator
$adminCheck = [System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $adminCheck.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    exit
}

# 1️⃣ Enable RDP via System Settings
Write-Host "Enabling Remote Desktop..." -ForegroundColor Green
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name PortNumber -Value 3389

# 2️⃣ Restart Remote Desktop Services
Write-Host "Restarting Remote Desktop Services..." -ForegroundColor Green
Stop-Service TermService -Force
Start-Service TermService

# 3️⃣ Enable RDP in Windows Firewall
Write-Host "Allowing RDP in Windows Firewall..." -ForegroundColor Green
netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
netsh advfirewall firewall add rule name="Allow RDP" protocol=TCP dir=in localport=3389 action=allow

# 4️⃣ Ensure RDP is listening on port 3389
Write-Host "Checking if RDP is listening on port 3389..." -ForegroundColor Green
$rdpListening = netstat -an | Select-String ":3389"
if ($rdpListening -match "LISTENING") {
    Write-Host "✅ RDP is listening on port 3389!" -ForegroundColor Green
} else {
    Write-Host "⚠️ RDP is NOT listening on port 3389. Attempting to restart TermService..." -ForegroundColor Yellow
    Stop-Service TermService -Force
    Start-Service TermService
    Start-Sleep -Seconds 5
    $rdpListening = netstat -an | Select-String ":3389"
    if ($rdpListening -match "LISTENING") {
        Write-Host "✅ RDP is now listening!" -ForegroundColor Green
    } else {
        Write-Host "❌ RDP is still not listening. Please check manually." -ForegroundColor Red
    }
}

# 5️⃣ Allow ICMP (Ping) in Windows Firewall
Write-Host "Allowing ICMP (Ping) in Windows Firewall..." -ForegroundColor Green
netsh advfirewall firewall add rule name="ICMP Allow" protocol="icmpv4:8,any" dir=in action=allow

# 6️⃣ Check and Repair Windows System Files (if needed)
Write-Host "Checking Windows for Corrupted Files..." -ForegroundColor Green
sfc /scannow
DISM /Online /Cleanup-Image /RestoreHealth

# 7️⃣ Final Check
Write-Host "✅ RDP Fix Script Completed! Restarting Remote Desktop Service one more time..." -ForegroundColor Cyan
Stop-Service TermService -Force
Start-Service TermService

Write-Host "🔄 Please restart the VM to apply changes!" -ForegroundColor Yellow
