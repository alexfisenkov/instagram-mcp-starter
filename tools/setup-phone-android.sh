#!/usr/bin/env bash
# ============================================================================
#  Метод 3 (телефон) — Android: установка adb + Appium (macOS / Linux)
#
#  Ставит инструменты для read-only управления Android-телефоном:
#    • platform-tools (adb) — скриншоты, дамп разметки экрана, тапы;
#    • appium + драйвер uiautomator2 — стабильная автоматизация;
#    • scrcpy (опционально) — зеркалирование экрана телефона на компьютер.
#
#  Запуск:
#    bash <(curl -fsSL https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/tools/setup-phone-android.sh)
#
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
OS="$(uname -s)"

pkg() { # pkg <brew> <apt> <dnf>
  if [[ "$OS" == "Darwin" ]]; then have brew && brew install "$1" || { err "Нужен Homebrew (https://brew.sh)"; return 1; }
  elif have apt-get; then sudo apt-get update -qq && sudo apt-get install -y "$2"
  elif have dnf; then sudo dnf install -y "$3"
  else err "Не знаю пакетный менеджер — поставьте $1 вручную"; return 1; fi
}

printf '\n%sМетод 3 (Android) — adb + Appium%s\n' "$C_B" "$C_O"

# adb
step "platform-tools (adb)"
if have adb; then ok "adb уже установлен ($(adb version 2>/dev/null | head -1))"
elif ask "Установить adb (platform-tools)?"; then
  if [[ "$OS" == "Darwin" ]]; then pkg android-platform-tools android-tools-adb android-tools
  else pkg adb android-tools-adb android-tools; fi
  have adb && ok "adb установлен"
fi

# Appium + uiautomator2
step "Appium + драйвер uiautomator2"
if ! have npm; then warn "npm не найден — Appium пропущен (Node.js ставится методом 1). Для базового чтения хватит adb."
else
  if have appium; then ok "appium уже установлен"
  elif ask "Установить Appium глобально (npm)?"; then npm install -g appium && ok "appium установлен"; fi
  if have appium; then
    if appium driver list --installed 2>/dev/null | grep -q uiautomator2; then ok "драйвер uiautomator2 уже установлен"
    elif ask "Установить драйвер uiautomator2?"; then appium driver install uiautomator2 && ok "драйвер установлен"; fi
  fi
fi

# scrcpy (опц.)
step "scrcpy — зеркало экрана (опционально)"
if have scrcpy; then ok "scrcpy уже установлен"
elif ask "Установить scrcpy? (удобно видеть экран телефона)"; then
  pkg scrcpy scrcpy scrcpy && ok "scrcpy установлен"
fi

# Проверка устройства
step "Проверка подключённого телефона"
if have adb; then
  echo "На телефоне: Настройки → О телефоне → 7 тапов по «Номер сборки»;"
  echo "затем Для разработчиков → включить «Отладка по USB»; подключить кабелем и «Разрешить»."
  if ask "Телефон уже подключён и настроен — проверить сейчас?"; then
    adb devices
    warn "Если статус 'unauthorized' — подтвердите отладку на телефоне; 'device' — всё готово."
  fi
fi

printf '\n%s✓ Готово.%s Плейбук: methods/03-phone.md (вариант B)\n' "$C_G" "$C_O"
echo "Быстрое чтение: adb exec-out screencap -p > screen.png ; adb exec-out uiautomator dump /dev/tty"
echo "Напоминание: только чтение своего аккаунта; UDID/серийники в отчёты не сохранять."
