#Admin auth
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Wymagane uprawnienia Administratora do zmiany sieci. Restartuje..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

function Start-Honey {
    Write-Host "--- Uruchamianie Honeypota ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose up -d
    Write-Host "Gotowe. Wciśnij DOWOLNY klawisz by wrocic"
}

function Stop-Honey {
    Write-Host "--- Zatrzymywanie Honeypota ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose down
}

function Reload-Honey {
    Write-Host "--- Usuniecie Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose down
    Write-Host "--- Czyszczenie Pamieci ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker system prune -a --volumes -f
    Write-Host "--- Budowa i uruchamianie Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose build --no-cache
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose up -d
    Write-Host "GOTOWE, SRODOWISKO PRZELADOWANE" -ForegroundColor Green
}


function LabOn {
    Write-Host "--- LAB ON: Izolacja + Statyczne IP ---" -ForegroundColor Yellow
    Write-Host " [1/4] Wylaczanie Firewalla..." -NoNewline
    Set-NetFirewallProfile -All -Enabled "False"
    Write-Host " OK." -ForegroundColor Green
    #Wi-Fi
    Write-Host " [2/4] Odcinanie Wi-Fi..." -NoNewline
    Disable-NetAdapter -Name "Wi-Fi*" -Confirm:$false -ErrorAction SilentlyContinue
    Disable-NetAdapter -InterfaceDescription "Wireless*" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host " OK." -ForegroundColor Green
    #Ethernet Config
    Write-Host " [3/4] Konfiguracja Ethernet (192.168.1.10)..." -NoNewline
    Enable-NetAdapter -Name "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue
    #Cleaning, static IP
    Remove-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "192.168.1.10" -PrefixLength 24 -AddressFamily IPv4 -ErrorAction Stop | Out-Null
    Write-Host " OK." -ForegroundColor Green
    Write-Host "--- SUKCES: LAB GOTOWY (Ping dziala, Internetu brak) ---" -ForegroundColor Red
}


function LabOff {
    Write-Host "--- LAB OFF: Powrót do Internetu ---" -ForegroundColor Yellow
    #Firewall
    Write-Host " [1/4] Przywracanie Firewalla..." -NoNewline
    Set-NetFirewallProfile -All -Enabled "True"
    Write-Host " OK." -ForegroundColor Green
    #Wi-Fi
    Write-Host " [2/4] Wlaczanie Wi-Fi..." -NoNewline
    Enable-NetAdapter -Name "Wi-Fi*" -Confirm:$false -ErrorAction SilentlyContinue
    Enable-NetAdapter -InterfaceDescription "Wireless*" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host " OK." -ForegroundColor Green
    #Ethernet
    Write-Host " [3/4] Resetowanie Ethernet do DHCP..." -NoNewline
    Enable-NetAdapter -Name "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue
    
    Remove-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "192.168.1.10" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Remove-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    #DHCP & DNS reset
    Set-NetIPInterface -InterfaceAlias "Ethernet" -Dhcp Enabled -AddressFamily IPv4 -ErrorAction SilentlyContinue
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses -ErrorAction SilentlyContinue
    Write-Host " OK." -ForegroundColor Green
    #NIC reset
    Write-Host " [4/4] Restart sterownika karty..." -NoNewline
    Restart-NetAdapter -Name "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host " OK." -ForegroundColor Green
    Write-Host "--- INTERNET PRZYWROCONY ---" -ForegroundColor Green
}

function Show-Honey {
    Write-Host "--- Stan Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose ps
}

do {
    #GUI colors
    $host.UI.RawUI.BackgroundColor = "Black"
    $host.UI.RawUI.ForegroundColor = "Green"
   
    Clear-Host
    Write-Host "==================CENTRUM STEROWANIA HONEYPOTEM===================" -ForegroundColor Cyan
    Write-Host " Dostepne komendy:" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host " [1] Start-Honey " -ForegroundColor Yellow -NoNewline 
    Write-Host "     - Uruchamia kontenery"
    Write-Host " [2] Stop-Honey" -ForegroundColor Yellow -NoNewline     
    Write-Host "       - Zatrzymuje i usuwa kontenery"
    Write-Host " [3] Reload-Honey"   -ForegroundColor Yellow -NoNewline
    Write-Host "     - Przebudowuje od zera"
    Write-Host " [4] Show-Honey "    -ForegroundColor Yellow -NoNewline
    Write-Host "      - Pokazuje status (docker ps)"
    Write-Host " [5] Lab-ON "        -ForegroundColor Yellow -NoNewline
    Write-Host "          - Uruchamia tryb laboratoryjny (OFFLINE)"
    Write-Host " [6] Lab-OFF  "     -ForegroundColor Yellow -NoNewline 
    Write-Host "        - Wylacza tryb laboratoryjny (ONLINE)"
    Write-Host " [q] Wyjscie" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan

    Write-Host " Wybierz opcje z listy: " -ForegroundColor Yellow -NoNewline
    $wybor = Read-Host
    switch ($wybor) {
        '1' { Start-Honey; Pause }
        '2' { Stop-Honey; Pause }
        '3' { Reload-Honey; Pause }
        '4' { Show-Honey; Pause }
        '5' { LabON; Pause }
        '6' { LabOFF; Pause }
        'q' { Write-Host "Do zobaczenia... "; break }
        Default { Write-Host "Nie ma takiej opcji." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }

} while ($wybor -ne 'q')
