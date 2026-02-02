# --- SPRAWDZENIE UPRAWNIEŃ ADMINA (Musi być na samej górze) ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Wymagane uprawnienia Administratora do zmiany sieci. Restartuje..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# --- DEFINICJE FUNKCJI ---

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
    Write-Host "--- LAB ON: ODLACZANIE od sieci ---" -ForegroundColor Yellow

    Get-NetAdapter |
        Where-Object {
            $_.Status -eq "Up" -and
            $_.Name -notmatch "Loopback"
        } |
        Disable-NetAdapter -Confirm:$false

    Write-Host "SIEC WYLACZONA." -ForegroundColor Red
}


function LabOff {
    Write-Host "--- LAB OFF: PRZYWRACANIE do sieci ---" -ForegroundColor Yellow

    Get-NetAdapter |
        Where-Object { $_.Status -ne "Up" } |
        Enable-NetAdapter -Confirm:$false

    Write-Host "SIEC WLACZONA." -ForegroundColor Red
}
function Show-Honey {
    Write-Host "--- Stan Kontenerow ---" -ForegroundColor Cyan
    wsl -d Ubuntu --cd ~/Honeypot -e docker compose ps
}

# --- GŁÓWNA PĘTLA PROGRAMU ---

do {
    # Naprawa kolorów po wyjściu z WSL/Linuxa
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