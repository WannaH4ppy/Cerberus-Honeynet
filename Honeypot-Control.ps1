#Admin auth
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Wymagane uprawnienia Administratora do zmiany sieci. Restartuje..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}


function Fix-Port-Reservations {
    Write-Host "--- Sprawdzanie rezerwacji portow ---" -ForegroundColor Cyan

    $myPorts = @(21, 22, 23, 80, 1445, 1433, 2222, 3000, 3100, 3306, 9000)
    
    #Out-String zamienia listę linii na jeden blok tekstu
    $currentExclusions = netsh interface ipv4 show excludedportrange protocol=tcp | Out-String
    $toAdd = @()

    foreach ($port in $myPorts) {
        # Precyzyjniejsze szukanie (port na początku linii + spacje)
        # (?m) włącza tryb wielolinijkowy, ^ to początek linii
        if ($currentExclusions -notmatch "(?m)^\s*$port\s") {
            $toAdd += $port
        }
    }

    if ($toAdd.Count -gt 0) {
        Write-Host "Brakuje rezerwacji dla: $($toAdd -join ', '). Naprawiam..." -ForegroundColor Yellow
        # 1. Zatrzymujemy winnat
        Stop-Service winnat -Force -ErrorAction SilentlyContinue
        # 2. CZEKAMY
        Start-Sleep -Seconds 3 

        foreach ($port in $toAdd) {
            # Dodajemy rezerwację
            netsh int ipv4 add excludedportrange protocol=tcp startport=$port numberofports=1 store=persistent 2>$null
        }

        # 3. Przywracamy sieć
        Start-Service winnat
        Write-Host "Porty zostaly zarezerwowane pomyslnie." -ForegroundColor Green
    } else {
        Write-Host "Wszystkie porty sa juz bezpieczne." -ForegroundColor Green
    }
}

function Test-HoneyHealth {
    Write-Host "`n--- [WERYFIKACJA] Sprawdzanie dostepnosci uslug ---" -ForegroundColor Cyan
    $portsToTest = @(
        @{Port=22;   Name="Cowrie SSH"};
        @{Port=21;   Name="Dionaea FTP"};
        @{Port=42;   Name="Dionaea HNS"};
        @{Port=80;   Name="Dionaea HTTP"};
        @{Port=135; Name="Dionaea RPC"};
        @{Port=2222;   Name="Real-OS SSH"};
        @{Port=3306; Name="Dionaea MySQL"};
        @{Port=3000; Name="Grafana UI"};
        @{Port=9000; Name="Portainer UI"}
    )

    foreach ($service in $portsToTest) {
        $check = Test-NetConnection -ComputerName 127.0.0.1 -Port $service.Port -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($check) {
            Write-Host " [OK] " -NoNewline -ForegroundColor Green
            Write-Host "$($service.Name) (Port $($service.Port)) odpowiada."
        } else {
            Write-Host " [!!] " -NoNewline -ForegroundColor Red
            Write-Host "$($service.Name) (Port $($service.Port)) NIE ODPOWIADA!" -ForegroundColor Red
        }
    }
}

function Start-Honey {
    
    Fix-Port-Reservations
    Write-Host "--- Uruchamianie Honeypota ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose up -d
    Write-Host "--- Uruchomienie uslug ---" -ForegroundColor Cyan
    Start-Sleep -Seconds 20
    Test-HoneyHealth
    Write-Host "Gotowe. Wcisnij DOWOLNY klawisz by wrocic"
}

function Stop-Honey {
    Write-Host "--- Zatrzymywanie Honeypota ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose down
}

function Reload-Honey {
    Write-Host "--- Usuniecie Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose restart
    Write-Host "GOTOWE, SRODOWISKO PRZELADOWANE" -ForegroundColor Green
}

function Reload-HoneyADV {
    Write-Host "--- Usuniecie Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose down
    Write-Host "--- Czyszczenie Pamieci ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker system prune -a --volumes -f
    Write-Host "--- Budowa i uruchamianie Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose build --no-cache
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose up -d
    Write-Host "GOTOWE, SRODOWISKO PRZELADOWANE" -ForegroundColor Green
}

function Real-OS {
    Write-Host "--- Inicjalizacja Honeypota --- " -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker exec -it REAL-OS /bin/bash

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
    Write-Host "--- INTERNET PRZYWROCONY ---" -ForegroundColor Red
}

function Show-Honey {
    Write-Host "--- Stan Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose ps --services --filter "status=running"
}

function Show-HoneyADV {
    Write-Host "--- Zaawansowane informacje o stanie Kontenerow" -ForegroundColor Cyan
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
    Write-Host "     - Szybki restart"
    Write-Host " [4] Reload-HoneyADV" -ForegroundColor Yellow -NoNewline
    Write-Host "  - Przebudowuje od zera"
    Write-Host " [5] Show-Honey "    -ForegroundColor Yellow -NoNewline
    Write-Host "      - Pokazuje uruchomione honeypoty"
    Write-Host " [6] Show-Honey+ "   -ForegroundColor Yellow -NoNewline
    Write-Host "     - Pokazuje szczegolowy status"
    Write-Host " [7] Lab-ON "        -ForegroundColor Yellow -NoNewline
    Write-Host "          - Uruchamia tryb laboratoryjny (OFFLINE)"
    Write-Host " [8] Lab-OFF  "     -ForegroundColor Yellow -NoNewline 
    Write-Host "        - Wylacza tryb laboratoryjny (ONLINE)"
    Write-Host " [9] Real-OS  "     -ForegroundColor Yellow -NoNewline 
    Write-Host "        - Zarzadzanie honeypotem REAL-OS"
    Write-Host " [q] Wyjscie" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan

    Write-Host " Wybierz opcje z listy: " -ForegroundColor Yellow -NoNewline
    $wybor = Read-Host
    switch ($wybor) {
        '1' { Start-Honey; Pause }
        '2' { Stop-Honey; Pause }
        '3' { Reload-Honey; Pause }
        '4' { Reload-HoneyADV; Pause}
        '5' { Show-Honey; Pause }
        '6' { Show-HoneyADV; Pause}
        '7' { LabON; Pause }
        '8' { LabOFF; Pause }
        '9' {Real-OS; Pause}
        'q' { Write-Host "Koniec programu"; break }
        Default { Write-Host "Nie ma takiej opcji." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }

} while ($wybor -ne 'q')




