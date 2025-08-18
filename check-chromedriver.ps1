$LocalChromedriver = 'C:\browser\chromedriver.exe'

if (Test-Path -Path $LocalChromedriver -PathType Leaf) {
    $f = Get-Item -LiteralPath $LocalChromedriver
    Write-Host "OK: $($f.FullName) — Size: $($f.Length) B, Modified: $($f.LastWriteTime)"
} else {
    Write-Host "BRAK: Nie znaleziono chromedriver.exe w $LocalChromedriver"
}

try {
    $resp = Invoke-WebRequest -Uri 'https://googlechromelabs.github.io/chrome-for-testing/' -ErrorAction Stop
    $html = $resp.Content

    $m = [regex]::Match($html, '(?si)https?://\S*chromedriver\S*win64\S*?\.zip')

    if (-not $m.Success) {
        $m = [regex]::Match($html, '(?si)<tr\b[^>]*>.*?chromedriver.*?win64.*?<a[^>]+href=["'](?<h>[^"']+?) ["']')
    }

    if ($m.Success) {
        $url = if ($m.Groups.Count -gt 1 -and $m.Groups['h']) { $m.Groups['h'].Value } elseif ($m.Groups.Count -gt 1) { $m.Groups[1].Value } else { $m.Value }

        if ($url -notmatch '^https?://') {
            $url = (New-Object System.Uri((New-Object System.Uri('https://googlechromelabs.github.io')),$url)).AbsoluteUri
        }

        Write-Host "Znaleziony link: $url"

        $yn = Read-Host 'Czy chcesz pobrać i zastąpić chromedriver w C:\browser? (t/n)'
        if ($yn -match '^(t|T|y|Y)') {
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

            $found = Get-ChildItem -Path $extractDir -Recurse -Filter 'chromedriver.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($found) {
                $browserDir = Split-Path -Path $LocalChromedriver -Parent
                if (-not (Test-Path $browserDir)) { New-Item -ItemType Directory -Path $browserDir | Out-Null }

                if (Test-Path $LocalChromedriver) {
                    $bak = $LocalChromedriver + '.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
                    Write-Host "Tworzę kopię zapasową istniejącego chromedriver: $bak"
                    Move-Item -LiteralPath $LocalChromedriver -Destination $bak -Force
                }

                Copy-Item -LiteralPath $found.FullName -Destination $LocalChromedriver -Force
                Write-Host "Zastąpiono chromedriver w $LocalChromedriver"
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

# Otwórz Chrome na stronie chrome://settings/help
$target = 'chrome://settings/help'
$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
)
$chrome = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($chrome) {
    Start-Process -FilePath $chrome -ArgumentList $target
} else {
    Start-Process $target
}