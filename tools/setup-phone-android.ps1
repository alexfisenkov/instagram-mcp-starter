# ============================================================================
#  Метод 3 (телефон) — Android: установка adb + Appium (Windows)
#
#  Ставит platform-tools (adb), Appium с драйвером uiautomator2 и, по желанию,
#  scrcpy (зеркало экрана). Для read-only управления Android-телефоном.
#
#  Запуск (PowerShell):
#    irm https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/tools/setup-phone-android.ps1 | iex
#
#  Всё ставится только с вашего согласия (y/n). Совместимо с PS 5.1 и 7+.
# ============================================================================

function Setup-PhoneAndroid {
$ErrorActionPreference = "Stop"

function Ask($q){ while($true){ $a=Read-Host "$q [y/n]"; if($a -match '^[YyДд]'){return $true}; if($a -match '^[NnНн]'){return $false}; Write-Host "y или n" } }
function Have($c){ [bool](Get-Command $c -ErrorAction SilentlyContinue) }
# Возвращает $true только при реальном успехе winget (native exit code 0)
function WingetInstall($id){ & winget install --id $id --accept-package-agreements --accept-source-agreements --silent; return ($LASTEXITCODE -eq 0) }

Write-Host "`nМетод 3 (Android) — adb + Appium" -ForegroundColor White
$winget = Have winget

# adb
Write-Host "`n==> platform-tools (adb)" -ForegroundColor Cyan
if (Have adb) { Write-Host "[OK] adb уже установлен" -ForegroundColor Green }
elseif (Ask "Установить adb (platform-tools)?") {
    if ($winget -and (WingetInstall "Google.PlatformTools")) { Write-Host "[OK] adb установлен (перезапустите PowerShell для PATH)" -ForegroundColor Green }
    else { Write-Host "[!] Не удалось поставить через winget — скачайте platform-tools с https://developer.android.com/tools/releases/platform-tools" -ForegroundColor Yellow }
}

# Appium + uiautomator2
Write-Host "`n==> Appium + драйвер uiautomator2" -ForegroundColor Cyan
if (-not (Have npm)) {
    Write-Host "[!] npm не найден — Appium пропущен (Node.js ставится методом 1). Для базового чтения хватит adb." -ForegroundColor Yellow
} else {
    if (Have appium) { Write-Host "[OK] appium уже установлен" -ForegroundColor Green }
    elseif (Ask "Установить Appium глобально (npm)?") { & npm install -g appium; Write-Host "[OK] appium установлен" -ForegroundColor Green }
    if (Have appium) {
        $installed = (& appium driver list --installed 2>&1) -join " "
        if ($installed -match "uiautomator2") { Write-Host "[OK] драйвер uiautomator2 уже установлен" -ForegroundColor Green }
        elseif (Ask "Установить драйвер uiautomator2?") { & appium driver install uiautomator2; Write-Host "[OK] драйвер установлен" -ForegroundColor Green }
    }
}

# scrcpy (опц.)
Write-Host "`n==> scrcpy — зеркало экрана (опционально)" -ForegroundColor Cyan
if (Have scrcpy) { Write-Host "[OK] scrcpy уже установлен" -ForegroundColor Green }
elseif (Ask "Установить scrcpy?") {
    if ($winget -and (WingetInstall "Genymobile.scrcpy")) { Write-Host "[OK] scrcpy установлен" -ForegroundColor Green }
    else { Write-Host "[!] Не удалось поставить через winget — скачайте scrcpy с https://github.com/Genymobile/scrcpy" -ForegroundColor Yellow }
}

# Проверка
Write-Host "`n==> Проверка подключённого телефона" -ForegroundColor Cyan
Write-Host "На телефоне: Настройки -> О телефоне -> 7 тапов по «Номер сборки»;"
Write-Host "затем Для разработчиков -> включить «Отладка по USB»; подключить кабелем и «Разрешить»."
if ((Have adb) -and (Ask "Телефон подключён — проверить сейчас?")) {
    & adb devices
    Write-Host "[!] 'unauthorized' — подтвердите отладку на телефоне; 'device' — всё готово." -ForegroundColor Yellow
}

Write-Host "`n[OK] Готово. Плейбук: methods/03-phone.md (вариант B)" -ForegroundColor Green
Write-Host "Напоминание: только чтение своего аккаунта; UDID/серийники в отчёты не сохранять."
}

Setup-PhoneAndroid
