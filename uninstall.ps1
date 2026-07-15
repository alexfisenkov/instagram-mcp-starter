# ============================================================================
#  Instagram MCP Starter — полное удаление (Windows)
#
#  Запуск (PowerShell):
#    irm https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/uninstall.ps1 | iex
#
#  Удаляет: сервер, ключи, токен, записи в конфигах Claude Code и Claude Desktop.
#  ВАЖНО: после удаления отзовите доступ приложения:
#  Instagram -> Настройки -> Безопасность -> Приложения и сайты.
# ============================================================================

function Uninstall-InstagramMcp {

$ErrorActionPreference = "Stop"

$BaseDir    = Join-Path $env:USERPROFILE ".instagram-mcp"
$TokenStore = Join-Path $env:USERPROFILE ".config\meta-instagram-mcp"
$MergerJs   = Join-Path $BaseDir "app\merge-config.mjs"

$answer = Read-Host "Удалить Instagram MCP полностью ($BaseDir, токен и записи в конфигах)? [y/n]"
if ($answer -notmatch '^[YyДд]') { Write-Host "Отменено."; return }

# 1. Claude Code
if (Get-Command claude -ErrorAction SilentlyContinue) {
    try {
        $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & claude mcp remove instagram -s user 2>$null | Out-Null
    } catch { } finally { $ErrorActionPreference = $eap }
    Write-Host "[OK] Удалён из Claude Code (если был подключён)"
}

# 2. Claude Desktop (с резервной копией)
$DesktopCfg = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
$NodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ((Test-Path $DesktopCfg) -and (Test-Path $MergerJs) -and $NodeCmd) {
    & $NodeCmd.Source $MergerJs $DesktopCfg instagram --remove
}

# 3. Файлы и токен
if (Test-Path $BaseDir) {
    Remove-Item -Recurse -Force $BaseDir
    Write-Host "[OK] Удалена папка $BaseDir (сервер и ключи)"
}
if (Test-Path $TokenStore) {
    Remove-Item -Recurse -Force $TokenStore
    Write-Host "[OK] Удалён token-store $TokenStore"
}

Write-Host ""
Write-Host "Готово. Последний шаг — отзовите доступ приложения:"
Write-Host "  Instagram -> Настройки -> Безопасность -> Приложения и сайты -> удалить приложение."
Write-Host "Само Meta-приложение можно удалить на developers.facebook.com (или оставить на будущее)."

}

Uninstall-InstagramMcp
