<#
  check-chromedriver.ps1
  - Sprawdza czy istnieje C:\browser\chromedriver.exe (wypisuje info)
  - Pobiera stronę https://googlechromelabs.github.io/chrome-for-testing/
  - Znajduje link do chromedriver-win64.zip
  - Pyta, czy pobrać i zastąpić chromedriver w C:\browser (tworzy backup)
  - Pobiera zip do %USERPROFILE%\Pobrane, rozpakowuje, wyszukuje chromedriver.exe w podfolderach
  - Kopiuje nowy chromedriver.exe do C:\browser\chromedriver.exe (backup oryginału)
  Uwaga: uruchamiaj tylko z zaufanego źródła (iex (irm '...') jest ryzykowne).
#>

# Ścieżka docelowa chromedrivera lokalnie
$LocalChromedriver = 'C:\browser\chromedriver.exe'

# Wyświetl status lokalnego pliku (jeśli istnieje)
if (Test-Path -Path $LocalChromedriver -PathType Leaf) {
    $f = Get-Item -LiteralPath $LocalChromedriver
    Write-Host "OK: $($f.FullName) — Size: $($f.Length) B, Modified: $($f.LastWriteTime)"
} else {
    Write-Host "BRAK: Nie znaleziono chromedriver.exe w $LocalChromedriver"
}

try {
    # Pobierz stronę chrome-for-testing
    $resp = Invoke-WebRequest -Uri 'https://googlechromelabs.github.io/chrome-for-testing/' -ErrorAction Stop
    $html = $resp.Content

    # Spróbuj znaleźć bezpośredni URL do zip (najpierw prosty regex)
    $m = [regex]::Match($html, '(?si)https?://\S*chromedriver\S*win64\S*?\.zip')

    # Jeśli prosty regex nie zadziała, spróbuj dopasowania tr/ href
    if (-not $m.Success) {
        $m = [regex]::Match($html, '(?si)<tr\b[^>]*>.*?chromedriver.*?win64.*?<a[^>]+href=["''](?<h>[^"''>]+)["'']')
    }

    if ($m.Success) {
        # Pobierz URL z grupy, jeśli istnieje, inaczej z wartości
        $url = if ($m.Groups.Count -gt 1 -and $m.Groups['h']) { $m.Groups['h'].Value } elseif ($m.Groups.Count -gt 1) { $m.Groups[1].Value } else { $m.Value }

        # Upewnij się, że jest to pełny URL
        if ($url -notmatch '^https?://') {
            $url = (New-Object System.Uri((New-Object System.Uri('https://googlechromelabs.github.io')),$url)).AbsoluteUri
        }

        Write-Host "Znaleziony link: $url"

        # Zapytaj użytkownika
        $yn = Read-Host 'Czy chcesz pobrać i zastąpić chromedriver w C:\browser? (t/n)'
        if ($yn -match '^(t|T|y|Y)') {
            # Przygotuj katalog pobranych plików
            $downloads = Join-Path $env:USERPROFILE 'Pobrane'
            if (-not (Test-Path $downloads)) { New-Item -ItemType Directory -Path $downloads | Out-Null }

            $fileName = [System.IO.Path]::GetFileName([uri]$url).TrimEnd('/')
            $zipPath = Join-Path $downloads $fileName

            Write-Host "Pobieram do $zipPath ..."
            Invoke-WebRequest -Uri $url -OutFile $zipPath -ErrorAction Stop

            $extractDir = Join-Path $downloads ([System.IO.Path]::GetFileNameWithoutExtension($fileName))
            if (-not (Test-Path $extractDir)) { New-Item -ItemType Directory -Path $extractDir | Out-Null }

            Write-Host "Rozpakowuję do $extractDir ..."
            Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
            Start-Sleep -Milliseconds 200

            # Znajdź rzeczywisty chromedriver.exe w rozpakowanym drzewie
            $found = Get-ChildItem -Path $extractDir -Recurse -Filter 'chromedriver.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($found) {
                # Przygotuj katalog C:\browser
                $browserDir = Split-Path -Path $LocalChromedriver -Parent
                if (-not (Test-Path $browserDir)) { New-Item -ItemType Directory -Path $browserDir | Out-Null }

                # Utwórz backup istniejącego pliku, jeśli istnieje
                if (Test-Path $LocalChromedriver) {
                    $bak = $LocalChromedriver + '.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
                    Write-Host "Tworzę kopię zapasową istniejącego chromedriver: $bak"
                    Move-Item -LiteralPath $LocalChromedriver -Destination $bak -Force
                }

                # Skopiuj nowy chromedriver.exe na miejsce
                Copy-Item -LiteralPath $found.FullName -Destination $LocalChromedriver -Force
                Write-Host "Zastąpiono chromedriver w $LocalChromedriver"

                # (Opcjonalnie) usuń zip — odkomentuj poniższą linię jeśli chcesz usuwać zip
                # Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue

            } else {
                Write-Host "Nie znaleziono chromedriver.exe w rozpakowanym archiwum."
            }
        } else {
            Write-Host 'Pominięto pobieranie.'
        }
    } else {
        Write-Host 'Nie znaleziono pasującego linku na stronie (struktura mogła się zmienić).'
    }
} catch {
    Write-Host "Błąd: $($_.Exception.Message)"
}