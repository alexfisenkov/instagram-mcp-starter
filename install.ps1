# ============================================================================
#  Instagram MCP Starter — установщик для Windows (PowerShell)
#
#  Подключает ваш Instagram (официальный Meta Graph API, read-only)
#  к Claude (Desktop / Code / Cursor / Codex).
#
#  Запуск одной командой (PowerShell):
#    irm https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/install.ps1 | iex
#
#  Если Windows блокирует запуск скриптов:
#    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
#
#  Авторизация в Instagram (OAuth) выполняется ПОСЛЕ установки — через вашего
#  агента (AGENT.md) или вручную по docs/02-oauth.md.
#  Совместим с Windows PowerShell 5.1 и PowerShell 7+. Идемпотентен.
# ============================================================================

function Install-InstagramMcp {

$ErrorActionPreference = "Stop"

$RepoZip   = "https://github.com/alexfisenkov/instagram-mcp-starter/archive/refs/heads/main.zip"

$BaseDir   = Join-Path $env:USERPROFILE ".instagram-mcp"
$AppDir    = Join-Path $BaseDir "app"
$EnvFile   = Join-Path $BaseDir "instagram.env"
$RunCmd    = Join-Path $BaseDir "run.cmd"
$DoctorJs  = Join-Path $AppDir "doctor.mjs"
$MergerJs  = Join-Path $AppDir "merge-config.mjs"

function Write-Ok($msg)   { Write-Host "[OK] $msg"  -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[X]  $msg"  -ForegroundColor Red }
function Write-Warn2($msg){ Write-Host "[!]  $msg"  -ForegroundColor Yellow }
function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Ask-YesNo($question) {
    while ($true) {
        $answer = Read-Host "$question [y/n]"
        if ($answer -match '^[YyДд]') { return $true }
        if ($answer -match '^[NnНн]') { return $false }
        Write-Host "Введите y (да) или n (нет)."
    }
}

function Read-Hidden($prompt) {
    $secure = Read-Host $prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    return $plain
}

Write-Host ""
Write-Host "Instagram MCP Starter — подключаем ваш Instagram к Claude" -ForegroundColor White
Write-Host "Официальный Meta Graph API | только чтение | Установка в: $BaseDir"
Write-Host ""

# ---------- шаг 1: Node.js --------------------------------------------------
Write-Step "Шаг 1/5 · Проверяю Node.js"

$NodeCmd = Get-Command node -ErrorAction SilentlyContinue
$NodeBin = $null
if ($NodeCmd) {
    $NodeBin = $NodeCmd.Source
} else {
    Write-Warn2 "Node.js не найден — попробую установить автоматически."
    $WingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($WingetCmd -and (Ask-YesNo "Установить Node.js LTS автоматически через winget?")) {
        & winget install --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent
        $Candidate = Join-Path $env:ProgramFiles "nodejs\node.exe"
        if (Test-Path $Candidate) {
            $NodeBin = $Candidate
            Write-Ok "Node.js установлен автоматически"
        }
    }
    if (-not $NodeBin) {
        Write-Err "Node.js так и не установлен."
        Write-Host "Установите вручную с https://nodejs.org (кнопка LTS), закройте и заново откройте PowerShell."
        return
    }
}
$NodeVersionRaw = (& $NodeBin -v)
$NodeMajor = [int]($NodeVersionRaw.TrimStart('v').Split('.')[0])
if ($NodeMajor -lt 20) {
    Write-Err "Найден Node.js $NodeVersionRaw, а нужен 20 или новее. Обновите с https://nodejs.org"
    return
}
Write-Ok "Node.js $NodeVersionRaw — подходит ($NodeBin)"

$NpmBin = Join-Path (Split-Path $NodeBin) "npm.cmd"
if (-not (Test-Path $NpmBin)) {
    $NpmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($NpmCmd) { $NpmBin = $NpmCmd.Source }
}
if (-not $NpmBin -or -not (Test-Path $NpmBin)) {
    Write-Err "npm не найден. Переустановите Node.js с https://nodejs.org"
    return
}
Write-Ok "npm $(& $NpmBin -v)"

# ---------- шаг 2: скачивание и сборка ----------------------------------------
Write-Step "Шаг 2/5 · Скачиваю и собираю MCP-сервер"

New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
$TmpZip = Join-Path $env:TEMP "instagram-mcp-starter.zip"
$TmpDir = Join-Path $env:TEMP ("igmcp-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
Invoke-WebRequest -Uri $RepoZip -OutFile $TmpZip
Expand-Archive -Path $TmpZip -DestinationPath $TmpDir -Force
$SrcDir = Get-ChildItem -Path $TmpDir -Directory | Where-Object { $_.Name -like "instagram-mcp-starter-*" } | Select-Object -First 1
if (-not $SrcDir) {
    Write-Err "Не удалось скачать исходники ($RepoZip)"
    return
}
if (Test-Path $AppDir) { Remove-Item -Recurse -Force $AppDir }
Move-Item $SrcDir.FullName $AppDir
Remove-Item $TmpZip -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

Push-Location $AppDir
try {
    & $NpmBin install --no-fund --no-audit --loglevel=error
    if ($LASTEXITCODE -ne 0) { Write-Err "npm install не удался — проверьте интернет и повторите."; return }
    & $NpmBin run build
    if ($LASTEXITCODE -ne 0) { Write-Err "Сборка не удалась."; return }
} finally {
    Pop-Location
}
if (-not (Test-Path (Join-Path $AppDir "dist\server.js"))) {
    Write-Err "Сборка не удалась: нет dist\server.js"
    return
}
Copy-Item (Join-Path $AppDir "tools\doctor.mjs") $DoctorJs -Force
Copy-Item (Join-Path $AppDir "tools\merge-config.mjs") $MergerJs -Force
Write-Ok "Сервер собран: $AppDir"

# обёртка запуска: секреты в instagram.env, а не в конфигах клиентов
$RunCmdContent = @'
@echo off
rem Instagram MCP launcher. Secrets live in instagram.env, not in client configs.
setlocal
set "ENV_FILE=%USERPROFILE%\.instagram-mcp\instagram.env"
if exist "%ENV_FILE%" for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do set "%%a=%%b"
"__NODE_BIN__" "%USERPROFILE%\.instagram-mcp\app\dist\server.js"
'@
if ($NodeBin -match '^[\x20-\x7E]+$') {
    $RunCmdContent = $RunCmdContent.Replace("__NODE_BIN__", $NodeBin)
} else {
    $RunCmdContent = $RunCmdContent.Replace("`"__NODE_BIN__`"", "node")
}
Set-Content -Path $RunCmd -Value $RunCmdContent -Encoding Ascii
Write-Ok "Служебные скрипты записаны (run.cmd, doctor.mjs, merge-config.mjs)"

# ---------- шаг 3: ключи Meta-приложения --------------------------------------
Write-Step "Шаг 3/5 · Ключи Meta-приложения (App ID / App Secret)"

Write-Host "Ключи создаются на https://developers.facebook.com — инструкция: docs/01-meta-app.md."
Write-Host "Если ключей ещё нет — можно пропустить: ваш агент поможет получить их позже (AGENT.md)."
Write-Host ""

$WriteEnv = $true
if (Test-Path $EnvFile) {
    Write-Ok "Файл с ключами уже существует: $EnvFile"
    if (Ask-YesNo "Оставить текущие ключи?") { $WriteEnv = $false }
}

if ($WriteEnv) {
    $AppId = ""
    $AppSecret = ""
    if (Ask-YesNo "У вас уже есть App ID и App Secret?") {
        while ($true) {
            $AppId = Read-Host "META_INSTAGRAM_APP_ID (только цифры)"
            if ($AppId -match '^\d+$') { break }
            Write-Warn2 "App ID — это число. Попробуйте ещё раз."
        }
        while ($true) {
            $AppSecret = Read-Hidden "META_INSTAGRAM_APP_SECRET (32 символа, ввод скрыт)"
            if ($AppSecret -match '^[a-fA-F0-9]{32}$') { break }
            Write-Warn2 "App Secret — 32 шестнадцатеричных символа. Попробуйте ещё раз."
        }
    } else {
        Write-Warn2 "Создаю заготовку — заполните её по docs/01-meta-app.md (или поручите агенту)."
    }
    $EnvContent = "META_AUTH_MODE=facebook`r`nMETA_INSTAGRAM_APP_ID=$AppId`r`nMETA_INSTAGRAM_APP_SECRET=$AppSecret`r`nMETA_INSTAGRAM_REDIRECT_URI=http://localhost:8787/callback"
    Set-Content -Path $EnvFile -Value $EnvContent -Encoding Ascii
    try {
        icacls $EnvFile /inheritance:r /grant:r "${env:USERNAME}:(R,W)" | Out-Null
        Write-Ok "Файл ключей сохранён, доступ ограничен: $EnvFile"
    } catch {
        Write-Ok "Файл ключей сохранён: $EnvFile"
    }
}

# ---------- шаг 4: подключение к клиентам -------------------------------------
Write-Step "Шаг 4/5 · Подключаю к Claude"

$ClaudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($ClaudeCmd) {
    if (Ask-YesNo "Найден Claude Code. Подключить Instagram к Claude Code?") {
        try {
            $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            & claude mcp remove instagram -s user 2>$null | Out-Null
        } catch { } finally { $ErrorActionPreference = $eap }
        & claude mcp add instagram -s user -- cmd /c $RunCmd
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Готово. Проверка внутри Claude Code: наберите /mcp"
        } else {
            Write-Warn2 "Не удалось подключить автоматически — см. configs/"
        }
    }
} else {
    Write-Warn2 "Claude Code (команда claude) не найден — пропускаю."
}

$DesktopCfg = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
if ((Test-Path (Split-Path $DesktopCfg)) -or (Test-Path $DesktopCfg)) {
    if (Ask-YesNo "Найден Claude Desktop. Добавить Instagram в его конфиг (с резервной копией)?") {
        & $NodeBin $MergerJs $DesktopCfg instagram "cmd" "/c" $RunCmd
        if ($LASTEXITCODE -eq 0) {
            Write-Warn2 "Полностью перезапустите Claude Desktop (выход через значок в трее)."
        } else {
            Write-Warn2 "Не удалось изменить конфиг автоматически — пример: configs/claude_desktop_windows.example.json"
        }
    }
} else {
    Write-Warn2 "Claude Desktop не найден — пропускаю."
}

# ---------- шаг 5: проверка ----------------------------------------------------
Write-Step "Шаг 5/5 · Проверяю установку (doctor)"

& $NodeBin $DoctorJs "cmd" "/c" $RunCmd
if ($LASTEXITCODE -eq 0) {
    Write-Ok "Всё готово — сервер работает и авторизован!"
} else {
    Write-Warn2 "Сервер установлен. Следующий шаг — ключи и авторизация (см. итог ниже)."
}

# ---------- итог ----------------------------------------------------------------
Write-Host ""
Write-Host "================= УСТАНОВКА ЗАВЕРШЕНА =================" -ForegroundColor Green
Write-Host ""
Write-Host "Что установлено:"
Write-Host "  • Сервер:    $AppDir (собран из исходников)"
Write-Host "  • Ключи:     $EnvFile"
Write-Host "  • Запуск:    $RunCmd"
Write-Host "  • Проверка:  node `"$DoctorJs`" cmd /c `"$RunCmd`""
Write-Host ""
Write-Host "СЛЕДУЮЩИЙ ШАГ — авторизация в Instagram. Скажите своему Claude:" -ForegroundColor White
Write-Host ""
Write-Host "  «Прочитай https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/AGENT.md"
Write-Host "   и подключи мой Instagram по этой инструкции»"
Write-Host ""
Write-Host "Вручную: docs/01-meta-app.md (ключи) -> docs/02-oauth.md (вход)."
Write-Host ""
Write-Host "Безопасность: instagram.env и token.json никому не передавайте (docs/SECURITY.md)." -ForegroundColor Yellow
Write-Host "Отозвать доступ: Instagram -> Настройки -> Безопасность -> Приложения и сайты."
Write-Host ""

}

Install-InstagramMcp
