#!/usr/bin/env bash
# ============================================================================
#  Instagram MCP Starter — установщик для macOS и Linux
#
#  Подключает ваш Instagram (официальный Meta Graph API, read-only)
#  к Claude (Desktop / Code / Cursor / Codex).
#
#  Запуск одной командой:
#    bash <(curl -fsSL https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/install.sh)
#
#  Что делает скрипт:
#    1. Проверяет Node.js 20+ (на чистом компьютере предложит установить сам)
#    2. Скачивает и собирает MCP-сервер в ~/.instagram-mcp/app
#    3. Спрашивает ключи Meta-приложения (можно пропустить и добавить позже)
#    4. Подключает сервер к Claude Code и/или Claude Desktop
#    5. Проверяет установку (doctor)
#
#  Авторизация в Instagram (OAuth) выполняется ПОСЛЕ установки — через вашего
#  агента (AGENT.md) или вручную по docs/02-oauth.md.
#
#  Скрипт идемпотентный: можно запускать повторно, ничего не сломает.
# ============================================================================
set -euo pipefail
umask 077

# Можно переопределить для тестов: INSTAGRAM_MCP_TARBALL=file:///... bash install.sh
REPO_TARBALL="${INSTAGRAM_MCP_TARBALL:-https://github.com/alexfisenkov/instagram-mcp-starter/archive/refs/heads/main.tar.gz}"

BASE_DIR="$HOME/.instagram-mcp"
APP_DIR="$BASE_DIR/app"
ENV_FILE="$BASE_DIR/instagram.env"
WRAPPER="$BASE_DIR/run.sh"
DOCTOR="$APP_DIR/doctor.mjs"
MERGER="$APP_DIR/merge-config.mjs"

# ---------- оформление ------------------------------------------------------
if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_OFF=""
fi
ok()   { printf '%s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
err()  { printf '%s✗%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; }
warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
step() { printf '\n%s%s==> %s%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_OFF"; }

ask_yn() {
  local answer
  while true; do
    if ! read -r -p "$1 [y/n]: " answer </dev/tty; then
      err "Не удалось прочитать ответ — запускайте установщик в обычном интерактивном терминале."
      exit 1
    fi
    case "$answer" in
      [YyДд]*) return 0 ;;
      [NnНн]*) return 1 ;;
      *) echo "Введите y (да) или n (нет)." ;;
    esac
  done
}

printf '%s\n' \
  "" \
  "${C_BOLD}Instagram MCP Starter${C_OFF} — подключаем ваш Instagram к Claude" \
  "Официальный Meta Graph API · только чтение · Установка в: $BASE_DIR" \
  ""

# ---------- шаг 1: Node.js --------------------------------------------------
step "Шаг 1/5 · Проверяю Node.js"

print_node_manual_help() {
  echo ""
  echo "Установите Node.js LTS (20 или новее) вручную и запустите скрипт ещё раз:"
  case "$(uname -s)" in
    Darwin)
      echo "  • Вариант 1: скачайте установщик с https://nodejs.org (кнопка LTS)"
      echo "  • Вариант 2 (если есть Homebrew): brew install node"
      ;;
    Linux)
      echo "  • Универсально (без sudo): установите nvm — https://github.com/nvm-sh/nvm"
      echo "  • Ubuntu/Debian:  sudo apt update && sudo apt install -y nodejs npm"
      ;;
  esac
}

install_node_auto() {
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        if ask_yn "Установить Node.js автоматически через Homebrew?"; then
          brew install node && return 0
        fi
        return 1
      fi
      if ask_yn "Установить Node.js LTS автоматически? (официальный установщик nodejs.org, спросит пароль администратора)"; then
        local pkg_name pkg_url tmp_pkg
        pkg_name="$(curl -fsSL "https://nodejs.org/dist/latest-v22.x/" | grep -oE 'node-v22[0-9.]+\.pkg' | head -1)"
        if [[ -z "$pkg_name" ]]; then
          err "Не удалось определить свежую версию Node.js — установите вручную."
          return 1
        fi
        pkg_url="https://nodejs.org/dist/latest-v22.x/$pkg_name"
        tmp_pkg="$(mktemp -d)/$pkg_name"
        echo "Скачиваю $pkg_url ..."
        curl -fL -o "$tmp_pkg" "$pkg_url"
        sudo installer -pkg "$tmp_pkg" -target / || return 1
        rm -f "$tmp_pkg"
        export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
        return 0
      fi
      return 1
      ;;
    Linux)
      if ask_yn "Установить Node.js LTS автоматически через nvm? (без прав администратора)"; then
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        # shellcheck source=/dev/null
        [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
        nvm install --lts && return 0
      fi
      return 1
      ;;
  esac
  return 1
}

NODE_BIN="$(command -v node || true)"
if [[ -z "$NODE_BIN" ]]; then
  warn "Node.js не найден — попробую установить автоматически."
  if install_node_auto; then
    hash -r 2>/dev/null || true
    NODE_BIN="$(command -v node || true)"
  fi
  if [[ -z "$NODE_BIN" ]]; then
    err "Node.js так и не установлен."
    print_node_manual_help
    exit 1
  fi
  ok "Node.js установлен автоматически"
fi

NODE_MAJOR="$("$NODE_BIN" -p 'process.versions.node.split(".")[0]')"
if [[ "$NODE_MAJOR" -lt 20 ]]; then
  err "Найден Node.js $("$NODE_BIN" -v), а нужен 20 или новее."
  print_node_manual_help
  exit 1
fi
ok "Node.js $("$NODE_BIN" -v) — подходит ($NODE_BIN)"

if ! command -v npm >/dev/null 2>&1; then
  err "npm не найден (ставится вместе с Node.js). Переустановите Node.js с https://nodejs.org"
  exit 1
fi
ok "npm $(npm -v)"

# ---------- шаг 2: скачивание и сборка сервера -------------------------------
step "Шаг 2/5 · Скачиваю и собираю MCP-сервер"

mkdir -p "$BASE_DIR"
chmod 700 "$BASE_DIR"

TMP_EXTRACT="$(mktemp -d)"
curl -fsSL "$REPO_TARBALL" | tar -xz -C "$TMP_EXTRACT"
SRC_DIR="$(find "$TMP_EXTRACT" -maxdepth 1 -type d -name 'instagram-mcp-starter-*' | head -1)"
if [[ -z "$SRC_DIR" ]]; then
  err "Не удалось скачать исходники ($REPO_TARBALL)"
  exit 1
fi
rm -rf "$APP_DIR"
mv "$SRC_DIR" "$APP_DIR"
rm -rf "$TMP_EXTRACT"

(cd "$APP_DIR" && npm install --no-fund --no-audit --loglevel=error && npm run build)
if [[ ! -f "$APP_DIR/dist/server.js" ]]; then
  err "Сборка не удалась: нет $APP_DIR/dist/server.js"
  exit 1
fi
cp "$APP_DIR/tools/doctor.mjs" "$DOCTOR"
ok "Сервер собран: $APP_DIR"

# merge-config для Claude Desktop (с резервной копией)
cat > "$MERGER" <<'EOF'
#!/usr/bin/env node
// Безопасно добавляет (или удаляет) MCP-сервер в JSON-конфиг клиента, с бэкапом.
// Использование:
//   node merge-config.mjs <config.json> <имя> <command> [args...]
//   node merge-config.mjs <config.json> <имя> --remove
import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync } from "node:fs";
import { dirname } from "node:path";

const [configPath, name, command, ...args] = process.argv.slice(2);
if (!configPath || !name || !command) {
  console.error("Использование: node merge-config.mjs <config.json> <имя> <command|--remove> [args...]");
  process.exit(2);
}

let config = {};
if (existsSync(configPath)) {
  const raw = readFileSync(configPath, "utf8");
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  copyFileSync(configPath, `${configPath}.backup-${stamp}`);
  if (raw.trim() !== "") {
    try {
      config = JSON.parse(raw);
    } catch {
      console.error(`✗ Файл повреждён (невалидный JSON): ${configPath}. Исправьте его вручную.`);
      process.exit(1);
    }
  }
} else {
  mkdirSync(dirname(configPath), { recursive: true });
}

config.mcpServers = config.mcpServers ?? {};
if (command === "--remove") {
  delete config.mcpServers[name];
  console.log(`✓ Сервер "${name}" удалён из ${configPath}`);
} else {
  config.mcpServers[name] = args.length > 0 ? { command, args } : { command };
  console.log(`✓ Сервер "${name}" добавлен в ${configPath}`);
}
writeFileSync(configPath, JSON.stringify(config, null, 2) + "\n");
EOF

# обёртка запуска: секреты в instagram.env, а не в конфигах клиентов
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="\$HOME/.instagram-mcp/instagram.env"
NODE_BIN="$NODE_BIN"
if [[ ! -x "\$NODE_BIN" ]]; then
  export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"
  NODE_BIN="\$(command -v node || true)"
fi
if [[ -z "\$NODE_BIN" ]]; then
  for cand in "\$HOME"/.nvm/versions/node/*/bin/node; do
    [[ -x "\$cand" ]] && NODE_BIN="\$cand"
  done
fi
if [[ -z "\$NODE_BIN" ]]; then
  echo "instagram-mcp: node не найден — запустите install.sh снова" >&2
  exit 127
fi
if [[ -f "\$ENV_FILE" ]]; then
  set -a
  source "\$ENV_FILE"
  set +a
fi
exec "\$NODE_BIN" "\$HOME/.instagram-mcp/app/dist/server.js"
EOF
chmod 700 "$WRAPPER"
ok "Служебные скрипты записаны (run.sh, doctor.mjs, merge-config.mjs)"

# ---------- шаг 3: ключи Meta-приложения -------------------------------------
step "Шаг 3/5 · Ключи Meta-приложения (App ID / App Secret)"

echo "Ключи создаются на https://developers.facebook.com — инструкция: docs/01-meta-app.md."
echo "Если ключей ещё нет — можно пропустить: ваш агент поможет получить их позже (AGENT.md)."
echo ""

WRITE_ENV=1
if [[ -f "$ENV_FILE" ]]; then
  ok "Файл с ключами уже существует: $ENV_FILE"
  if ask_yn "Оставить текущие ключи?"; then
    WRITE_ENV=0
  fi
fi

if [[ "$WRITE_ENV" -eq 1 ]]; then
  if ask_yn "У вас уже есть App ID и App Secret?"; then
    while true; do
      read -r -p "META_INSTAGRAM_APP_ID (только цифры): " IG_APP_ID </dev/tty \
        || { err "Не удалось прочитать ввод."; exit 1; }
      [[ "$IG_APP_ID" =~ ^[0-9]+$ ]] && break
      warn "App ID — это число. Попробуйте ещё раз."
    done
    while true; do
      read -r -s -p "META_INSTAGRAM_APP_SECRET (32 символа, ввод скрыт): " IG_APP_SECRET </dev/tty \
        || { err "Не удалось прочитать ввод."; exit 1; }
      printf '\n'
      [[ "$IG_APP_SECRET" =~ ^[a-fA-F0-9]{32}$ ]] && break
      warn "App Secret — 32 шестнадцатеричных символа. Попробуйте ещё раз."
    done
    cat > "$ENV_FILE" <<ENVEOF
META_AUTH_MODE=facebook
META_INSTAGRAM_APP_ID=$IG_APP_ID
META_INSTAGRAM_APP_SECRET=$IG_APP_SECRET
META_INSTAGRAM_REDIRECT_URI=http://localhost:8787/callback
ENVEOF
    chmod 600 "$ENV_FILE"
    ok "Ключи сохранены в $ENV_FILE (права 600)"
  else
    cat > "$ENV_FILE" <<ENVEOF
META_AUTH_MODE=facebook
META_INSTAGRAM_APP_ID=
META_INSTAGRAM_APP_SECRET=
META_INSTAGRAM_REDIRECT_URI=http://localhost:8787/callback
ENVEOF
    chmod 600 "$ENV_FILE"
    warn "Создана заготовка $ENV_FILE — заполните её по docs/01-meta-app.md (или поручите агенту)."
  fi
fi

# ---------- шаг 4: подключение к клиентам ------------------------------------
step "Шаг 4/5 · Подключаю к Claude"

if command -v claude >/dev/null 2>&1; then
  if ask_yn "Найден Claude Code. Подключить Instagram к Claude Code?"; then
    claude mcp remove instagram -s user >/dev/null 2>&1 || true
    if claude mcp add instagram -s user -- "$WRAPPER"; then
      ok "Готово. Проверка внутри Claude Code: наберите /mcp"
    else
      warn "Не удалось подключить автоматически — см. configs/"
    fi
  fi
else
  warn "Claude Code (команда claude) не найден — пропускаю."
fi

case "$(uname -s)" in
  Darwin) DESKTOP_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
  *)      DESKTOP_CFG="$HOME/.config/Claude/claude_desktop_config.json" ;;
esac

if [[ -d "$(dirname "$DESKTOP_CFG")" || -f "$DESKTOP_CFG" ]]; then
  if ask_yn "Найден Claude Desktop. Добавить Instagram в его конфиг (с резервной копией)?"; then
    if "$NODE_BIN" "$MERGER" "$DESKTOP_CFG" instagram "$WRAPPER"; then
      warn "Полностью перезапустите Claude Desktop (Cmd+Q / выйти и открыть заново)."
    else
      warn "Не удалось изменить конфиг автоматически — пример: configs/claude_desktop_macos_linux.example.json"
    fi
  fi
else
  warn "Claude Desktop не найден — пропускаю."
fi

# ---------- шаг 5: проверка ---------------------------------------------------
step "Шаг 5/5 · Проверяю установку (doctor)"

if "$NODE_BIN" "$DOCTOR" "$WRAPPER"; then
  ok "Всё готово — сервер работает и авторизован!"
else
  warn "Сервер установлен. Следующий шаг — ключи и авторизация (см. итог ниже)."
fi

# ---------- итог --------------------------------------------------------------
printf '\n%s%s================= УСТАНОВКА ЗАВЕРШЕНА =================%s\n' "$C_BOLD" "$C_GREEN" "$C_OFF"
cat <<SUMMARY

Что установлено:
  • Сервер:    $APP_DIR (собран из исходников)
  • Ключи:     $ENV_FILE (права 600)
  • Запуск:    $WRAPPER
  • Проверка:  "$NODE_BIN" "$DOCTOR" "$WRAPPER"

СЛЕДУЮЩИЙ ШАГ — авторизация в Instagram. Проще всего поручить агенту:
скажите своему Claude:

  «Прочитай https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/AGENT.md
   и подключи мой Instagram по этой инструкции»

Вручную: docs/01-meta-app.md (ключи) → docs/02-oauth.md (вход).

Безопасность: файлы instagram.env и token.json никому не передавайте
(docs/SECURITY.md). Отозвать доступ: Instagram → Настройки → Безопасность →
Приложения и сайты.

SUMMARY
