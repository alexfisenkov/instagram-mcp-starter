#!/usr/bin/env bash
# ============================================================================
#  Метод 2 (браузер) — установка сопутствующих инструментов (macOS / Linux)
#
#  Ставит тулинг для СКАЧИВАНИЯ своих медиа и обработки:
#    • gallery-dl — загрузка своих постов/Reels/каруселей;
#    • ffmpeg     — кадры и аудиодорожка (для расшифровки/OCR-препроцессинга).
#  По желанию — Playwright (управление внешним Chrome).
#
#  Запуск:
#    bash <(curl -fsSL https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/tools/setup-browser.sh)
#
#  Само управление браузером у агента обычно уже есть; этот скрипт — про
#  скачивание и обработку. Всё ставится только с вашего согласия (y/n).
# ============================================================================
set -euo pipefail

if [[ -t 1 ]]; then C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[1m'; C_O=$'\033[0m'; else C_G=""; C_Y=""; C_R=""; C_B=""; C_O=""; fi
ok(){ printf '%s✓%s %s\n' "$C_G" "$C_O" "$*"; }
warn(){ printf '%s!%s %s\n' "$C_Y" "$C_O" "$*"; }
err(){ printf '%s✗%s %s\n' "$C_R" "$C_O" "$*" >&2; }
step(){ printf '\n%s==> %s%s\n' "$C_B" "$*" "$C_O"; }
ask(){ local a; while true; do read -r -p "$1 [y/n]: " a </dev/tty || return 1; case "$a" in [YyДд]*) return 0;; [NnНн]*) return 1;; *) echo "y или n";; esac; done; }

OS="$(uname -s)"
have(){ command -v "$1" >/dev/null 2>&1; }

pkg_install() { # pkg_install <brew-name> <apt-name> <dnf-name>
  if [[ "$OS" == "Darwin" ]]; then
    have brew && brew install "$1" || { err "Нужен Homebrew (https://brew.sh) или поставьте $1 вручную"; return 1; }
  elif have apt-get; then sudo apt-get update -qq && sudo apt-get install -y "$2"
  elif have dnf; then sudo dnf install -y "$3"
  else err "Не знаю пакетный менеджер — поставьте $1 вручную"; return 1; fi
}

printf '\n%sМетод 2 (браузер) — сопутствующие инструменты%s\n' "$C_B" "$C_O"

# ffmpeg
step "ffmpeg (обработка видео/аудио)"
if have ffmpeg; then ok "ffmpeg уже установлен"
elif ask "Установить ffmpeg?"; then pkg_install ffmpeg ffmpeg ffmpeg && ok "ffmpeg установлен"; fi

# gallery-dl
step "gallery-dl (скачивание своих медиа)"
if have gallery-dl; then ok "gallery-dl уже установлен"
elif ask "Установить gallery-dl?"; then
  if have pipx; then pipx install gallery-dl
  elif have pip3; then pip3 install --user gallery-dl
  elif have python3; then python3 -m pip install --user gallery-dl
  else pkg_install python python3 python3 && python3 -m pip install --user gallery-dl; fi
  have gallery-dl && ok "gallery-dl установлен" || warn "gallery-dl поставлен в --user; добавьте ~/.local/bin в PATH"
fi

# Playwright (опционально)
step "Playwright (внешний браузер, опционально)"
if ask "Поставить Playwright + Chromium для управления внешним браузером? (можно пропустить, если у агента есть свой браузер)"; then
  if have npm; then
    npm install -g playwright && npx --yes playwright install chromium && ok "Playwright + Chromium установлены"
  else
    warn "npm не найден — Playwright пропущен (Node.js ставится основным установщиком)"
  fi
fi

printf '\n%s✓ Готово.%s Дальше — плейбук метода 2: methods/02-browser.md\n' "$C_G" "$C_O"
echo "Напоминание: скачивайте только СВОЁ и только для чтения; куки/токены не сохраняйте."
