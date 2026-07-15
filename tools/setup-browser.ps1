# ============================================================================
#  Метод 2 (браузер) — установка сопутствующих инструментов (Windows)
#
#  Ставит gallery-dl (скачивание своих медиа) и ffmpeg (обработка), по желанию
#  Playwright. Управление браузером у агента обычно уже есть; это про скачивание.
#
#  Запуск (PowerShell):
#    irm https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/tools/setup-browser.ps1 | iex
#
#  Всё ставится только с вашего согласия (y/n). Совместимо с PS 5.1 и 7+.
# ============================================================================

function Setup-Browser {
$ErrorActionPreference = "Stop"

function Ask($q){ while($true){ $a=Read-Host "$q [y/n]"; if($a -match '^[YyДд]'){return $true}; if($a -match '^[NnНн]'){return $false}; Write-Host "y или n" } }
function Have($c){ [bool](Get-Command $c -ErrorAction SilentlyContinue) }
# Возвращает $true только при реальном успехе winget (native exit code 0)
function WingetInstall($id){ & winget install --id $id --accept-package-agreements --accept-source-agreements --silent; return ($LASTEXITCODE -eq 0) }

Write-Host "`nМетод 2 (браузер) — сопутствующие инструменты" -ForegroundColor White

$winget = Have winget

# ffmpeg
Write-Host "`n==> ffmpeg" -ForegroundColor Cyan
if (Have ffmpeg) { Write-Host "[OK] ffmpeg уже установлен" -ForegroundColor Green }
elseif (Ask "Установить ffmpeg?") {
    if ($winget -and (WingetInstall "Gyan.FFmpeg")) { Write-Host "[OK] ffmpeg установлен (перезапустите PowerShell для PATH)" -ForegroundColor Green }
    else { Write-Host "[!] Не удалось поставить ffmpeg — скачайте вручную с https://ffmpeg.org" -ForegroundColor Yellow }
}

# gallery-dl (основной путь — pip; он кроссплатформенный и надёжный)
Write-Host "`n==> gallery-dl (скачивание своих медиа)" -ForegroundColor Cyan
if (Have gallery-dl) { Write-Host "[OK] gallery-dl уже установлен" -ForegroundColor Green }
elseif (Ask "Установить gallery-dl?") {
    $done = $false
    if (Have pip)      { & pip install --user gallery-dl;  if ($LASTEXITCODE -eq 0) { $done = $true } }
    elseif (Have pip3) { & pip3 install --user gallery-dl; if ($LASTEXITCODE -eq 0) { $done = $true } }
    if ($done) { Write-Host "[OK] gallery-dl установлен (pip --user; при 'команда не найдена' добавьте Scripts в PATH)" -ForegroundColor Green }
    else { Write-Host "[!] Нужен Python с pip (https://python.org) — затем: pip install --user gallery-dl" -ForegroundColor Yellow }
}

# Playwright (опц.)
Write-Host "`n==> Playwright (внешний браузер, опционально)" -ForegroundColor Cyan
if (Ask "Поставить Playwright + Chromium?") {
    if (Have npm) { & npm install -g playwright; & npx --yes playwright install chromium; Write-Host "[OK] Playwright установлен" -ForegroundColor Green }
    else { Write-Host "[!] npm не найден — Playwright пропущен" -ForegroundColor Yellow }
}

Write-Host "`n[OK] Готово. Дальше — methods/02-browser.md" -ForegroundColor Green
Write-Host "Напоминание: скачивайте только СВОЁ и только для чтения; куки/токены не сохраняйте."
}

Setup-Browser
