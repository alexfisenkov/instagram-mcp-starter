#!/usr/bin/env bash
# ============================================================================
#  Метод 3 (телефон) — iOS: установка Appium + XCUITest (только macOS)
#
#  Ставит инструменты для read-only управления iPhone:
#    • appium + драйвер appium-xcuitest-driver;
#    • ios-deploy (диагностика устройства);
#  проверяет наличие Xcode и запускает appium driver doctor xcuitest.
#
#  Запуск:
#    bash <(curl -fsSL https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/tools/setup-phone-ios.sh)
#
#  WebDriverAgent собирается через Xcode один раз — см. methods/03-phone.md.
#  Всё ставится только с вашего согласия (y/n).
# ============================================================================
set -euo pipefail

if [[ -t 1 ]]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[1m'; C_O=$'\033[0m'; else C_G=""; C_Y=""; C_R=""; C_B=""; C_O=""; fi
ok(){ printf '%s✓%s %s\n' "$C_G" "$C_O" "$*"; }
warn(){ printf '%s!%s %s\n' "$C_Y" "$C_O" "$*"; }
err(){ printf '%s✗%s %s\n' "$C_R" "$C_O" "$*" >&2; }
step(){ printf '\n%s==> %s%s\n' "$C_B" "$*" "$C_O"; }
ask(){ local a; while true; do read -r -p "$1 [y/n]: " a </dev/tty || return 1; case "$a" in [YyДд]*) return 0;; [NnНн]*) return 1;; *) echo "y или n";; esac; done; }
have(){ command -v "$1" >/dev/null 2>&1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  err "Управление iPhone возможно только с Mac (нужен Xcode/WebDriverAgent)."
  echo "Для Android с любого ПК используйте tools/setup-phone-android.sh"
  exit 1
fi

printf '\n%sМетод 3 (iOS) — Appium + XCUITest%s\n' "$C_B" "$C_O"

# Node/npm — обычно уже стоят после метода 1
step "Node.js / npm"
if ! have npm; then err "npm не найден. Сначала установите метод 1 (там ставится Node.js) или Node.js с https://nodejs.org"; exit 1; fi
ok "npm $(npm -v)"

# Xcode
step "Xcode"
if xcode-select -p >/dev/null 2>&1; then
  ok "Command Line Tools: $(xcode-select -p)"
else
  warn "Command Line Tools не найдены — ставлю (откроется системное окно)."
  xcode-select --install || true
fi
if [[ -d "/Applications/Xcode.app" ]]; then
  ok "Xcode.app найден"
else
  warn "Полноценный Xcode не найден. Установите его из App Store (большой, вручную) —"
  warn "без него WebDriverAgent не соберётся. После установки запустите Xcode один раз и войдите Apple ID."
fi

# ios-deploy
step "ios-deploy (диагностика устройства)"
if have ios-deploy; then ok "ios-deploy уже установлен"
elif ask "Установить ios-deploy?"; then
  if have brew; then brew install ios-deploy && ok "ios-deploy установлен"
  else npm install -g ios-deploy && ok "ios-deploy установлен (npm)"; fi
fi

# Appium + xcuitest
step "Appium + драйвер XCUITest"
if have appium; then ok "appium уже установлен ($(appium -v 2>/dev/null || echo '?'))"
elif ask "Установить Appium глобально (npm)?"; then npm install -g appium && ok "appium установлен"; fi
if have appium; then
  if appium driver list --installed 2>/dev/null | grep -q xcuitest; then
    ok "драйвер xcuitest уже установлен"
  elif ask "Установить драйвер xcuitest?"; then
    appium driver install xcuitest && ok "драйвер xcuitest установлен"
  fi
fi

# Doctor
step "Проверка окружения (appium driver doctor xcuitest)"
if have appium && ask "Запустить диагностику xcuitest сейчас? (подскажет, чего не хватает)"; then
  appium driver doctor xcuitest || warn "Доктор нашёл проблемы — см. его вывод и methods/03-phone.md"
fi

printf '\n%s✓ Готово.%s Дальше:\n' "$C_G" "$C_O"
echo "  1) Открыть Xcode, войти Apple ID (Settings → Accounts)."
echo "  2) iPhone: Настройки → Конфиденциальность → Режим разработчика → включить; подключить кабелем, «Доверять»."
echo "  3) Плейбук и сборка WebDriverAgent: methods/03-phone.md (вариант A)."
echo "Напоминание: только чтение своего аккаунта; UDID/серийники в отчёты не сохранять."
