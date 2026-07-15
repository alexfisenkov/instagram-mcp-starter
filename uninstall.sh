#!/usr/bin/env bash
# ============================================================================
#  Instagram MCP Starter — полное удаление (macOS / Linux)
#
#  Запуск:
#    bash <(curl -fsSL https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/uninstall.sh)
#
#  Удаляет: сервер, ключи, токен, записи в конфигах Claude Code и Claude Desktop.
#  ВАЖНО: после удаления отзовите доступ приложения:
#  Instagram → Настройки → Безопасность → Приложения и сайты.
# ============================================================================
set -euo pipefail

BASE_DIR="$HOME/.instagram-mcp"
TOKEN_STORE="$HOME/.config/meta-instagram-mcp"

read -r -p "Удалить Instagram MCP полностью ($BASE_DIR, токен и записи в конфигах)? [y/n]: " answer </dev/tty
case "$answer" in
  [YyДд]*) ;;
  *) echo "Отменено."; exit 0 ;;
esac

# 1. Claude Code
if command -v claude >/dev/null 2>&1; then
  claude mcp remove instagram -s user >/dev/null 2>&1 && echo "✓ Удалён из Claude Code" || true
fi

# 2. Claude Desktop (с резервной копией)
case "$(uname -s)" in
  Darwin) DESKTOP_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
  *)      DESKTOP_CFG="$HOME/.config/Claude/claude_desktop_config.json" ;;
esac
MERGER="$BASE_DIR/app/merge-config.mjs"
if [[ -f "$DESKTOP_CFG" && -f "$MERGER" ]] && command -v node >/dev/null 2>&1; then
  node "$MERGER" "$DESKTOP_CFG" instagram --remove || true
fi

# 3. Файлы (сервер, ключи) и токен
[[ -d "$BASE_DIR" ]] && rm -rf "$BASE_DIR" && echo "✓ Удалена папка $BASE_DIR (сервер и ключи)"
[[ -d "$TOKEN_STORE" ]] && rm -rf "$TOKEN_STORE" && echo "✓ Удалён token-store $TOKEN_STORE"

echo ""
echo "Готово. Последний шаг — отзовите доступ приложения:"
echo "  Instagram → Настройки → Безопасность → Приложения и сайты → удалить приложение."
echo "Само Meta-приложение можно удалить на developers.facebook.com (или оставить на будущее)."
