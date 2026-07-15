# AGENT.md — инструкция для AI-агента: подключи Instagram своего человека

> **Ты — AI-агент** (Claude Code, Claude Desktop, Codex, Cursor или другой), и твой человек попросил подключить его Instagram-аккаунт через этот проект. Этот файл — твой полный план действий. Выполняй этапы по порядку, после каждого проверяй контрольную точку. Человека привлекай только там, где без него нельзя: клики в интерфейсе Meta и вход в аккаунт.

## Что ты в итоге получишь

Локальный MCP-сервер `meta-instagram-mcp` (официальный Meta Graph API, только чтение): информация об аккаунте, список постов, комментарии и ответы, инсайты аккаунта и постов, рейтинг контента по вовлечённости, безопасный raw GET. 16 инструментов — полный список в [docs/TOOLS.md](docs/TOOLS.md).

## Предпосылки — проверь у человека ДО начала

Задай человеку три вопроса:

1. **«Ваш Instagram — профессиональный (Бизнес или Автор)?»** Если нет: попроси переключить (Instagram → Настройки → Тип аккаунта → Переключиться на профессиональный). Это бесплатно и обратимо. Личные аккаунты Meta API не обслуживает.
2. **«Есть ли у вас аккаунт Facebook и привязана ли к Instagram страница Facebook?»** Рекомендуемый путь (режим `facebook`) требует страницу FB, связанную с Instagram (Instagram → Настройки → Центр аккаунтов → или в настройках профиля «Страница»). Если страницы нет и заводить не хочет — используй альтернативный режим `instagram` (см. «Режим instagram» внизу).
3. **«Компьютер под macOS, Windows или Linux?»** — определяет команды ниже.

Также реши, как вы будете работать: если ты — Claude Code (есть терминал), выполняй команды сам. Если ты без терминала (Claude Desktop) — диктуй человеку команды по одной и проси вставлять вывод.

---

## Этап 0. Установка сервера

**Вариант А (человек запускает интерактивный установщик):** попроси человека выполнить в терминале и следовать вопросам:

```bash
# macOS / Linux
bash <(curl -fsSL https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/install.sh)
```

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/install.ps1 | iex
```

На вопрос про ключи Meta-приложения человек может ответить «нет» — вы заполните их на этапе 2.

**Вариант Б (ты — Claude Code и делаешь всё сам):** выполни те же установщики нельзя (они интерактивные), поэтому шаги вручную:

```bash
# macOS / Linux. Требуется Node.js 20+ (проверь: node -v)
mkdir -p ~/.instagram-mcp && chmod 700 ~/.instagram-mcp
curl -fsSL https://github.com/alexfisenkov/instagram-mcp-starter/archive/refs/heads/main.tar.gz | tar -xz -C ~/.instagram-mcp
rm -rf ~/.instagram-mcp/app && mv ~/.instagram-mcp/instagram-mcp-starter-main ~/.instagram-mcp/app
cd ~/.instagram-mcp/app && npm install --no-fund --no-audit && npm run build
cp tools/doctor.mjs ~/.instagram-mcp/app/doctor.mjs 2>/dev/null || true
```

Создай обёртку запуска (секреты будут в отдельном файле, не в конфигах клиентов):

```bash
cat > ~/.instagram-mcp/run.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="$HOME/.instagram-mcp/instagram.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }
exec node "$HOME/.instagram-mcp/app/dist/server.js"
EOF
chmod 700 ~/.instagram-mcp/run.sh
```

На Windows аналогично: скачай и распакуй архив в `%USERPROFILE%\.instagram-mcp\app`, `npm install && npm run build`, создай `run.cmd`:

```cmd
@echo off
setlocal
set "ENV_FILE=%USERPROFILE%\.instagram-mcp\instagram.env"
if exist "%ENV_FILE%" for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do set "%%a=%%b"
node "%USERPROFILE%\.instagram-mcp\app\dist\server.js"
```

**Контрольная точка 0:** `node ~/.instagram-mcp/app/doctor.mjs ~/.instagram-mcp/run.sh` печатает `✓ MCP-сервер запустился, инструментов: 16` (и предупреждение, что ключи не настроены — это пока норма).

---

## Этап 1. Meta-приложение (нужны клики человека)

Цель этапа: получить **App ID** и **App Secret** и прописать **redirect URI**. Это делается один раз на developers.facebook.com. Диктуй человеку по одному шагу, жди подтверждения.

> Интерфейс Meta периодически меняется. Если пункт называется иначе — ориентируйся на ЦЕЛЬ шага и помоги человеку найти аналог. Названия ниже даны на английском и русском.

1. «Откройте **https://developers.facebook.com** и войдите со своим аккаунтом Facebook. Если сайт предложит стать разработчиком (Get Started / Начать) — согласитесь, подтвердите телефон/почту».
2. «Справа вверху **My Apps / Мои приложения** → зелёная кнопка **Create App / Создать приложение**».
3. «Если спрашивает сценарий использования (use case) — выберите **Other / Другое**. Тип приложения — **Business / Бизнес**. Название — любое, например `My IG Analytics`. Создайте приложение (попросит пароль Facebook)».
4. «В панели приложения найдите **Add products / Добавить продукты** (или "Add products to your app"). Добавьте (кнопка Set up):
   - **Facebook Login** (или **Facebook Login for Business**);
   - **Instagram** / **Instagram Graph API** — если предлагает варианты настройки, выберите вариант **с Facebook login** (API setup with Facebook login)».
5. «Слева: **Facebook Login → Settings / Настройки**. В поле **Valid OAuth Redirect URIs** вставьте ровно: `http://localhost:8787/callback` и нажмите **Save changes**. Если рядом есть переключатели Client OAuth login / Web OAuth login — они должны быть включены».
6. «Слева: **App settings → Basic / Настройки → Основное**. Скопируйте **App ID** (число). Затем возле **App secret** нажмите **Show** (попросит пароль Facebook) и скопируйте секрет (32 символа)».
7. «Режим приложения оставьте **Development / Режим разработки»** — для работы со СВОИМ аккаунтом этого достаточно, проверка бизнеса не нужна».

Попроси человека передать тебе App ID и App Secret. Предупреди: «App Secret — это пароль приложения; я запишу его только в локальный файл с правами доступа только для вас». Если человек не хочет передавать секрет в чат — продиктуй ему команду с этапа 2 и попроси подставить секрет самостоятельно.

**Контрольная точка 1:** у тебя есть App ID (только цифры) и App Secret (32 hex-символа).

---

## Этап 2. Файл с ключами

```bash
# macOS / Linux — подставь реальные значения:
umask 077
cat > ~/.instagram-mcp/instagram.env <<'EOF'
META_AUTH_MODE=facebook
META_INSTAGRAM_APP_ID=ПОДСТАВЬ_APP_ID
META_INSTAGRAM_APP_SECRET=ПОДСТАВЬ_APP_SECRET
META_INSTAGRAM_REDIRECT_URI=http://localhost:8787/callback
EOF
chmod 600 ~/.instagram-mcp/instagram.env
```

На Windows — тот же файл `%USERPROFILE%\.instagram-mcp\instagram.env` (кодировка ASCII, CRLF не важен).

**Контрольная точка 2:** доктор теперь показывает `"hasAppId": true, "hasAppSecret": true, "hasRedirectUri": true`.

---

## Этап 3. Регистрация MCP в клиенте

```bash
# Claude Code (macOS/Linux):
claude mcp add instagram -s user -- "$HOME/.instagram-mcp/run.sh"
```

```powershell
# Claude Code (Windows):
claude mcp add instagram -s user -- cmd /c "$env:USERPROFILE\.instagram-mcp\run.cmd"
```

Для Claude Desktop / Cursor / Codex — готовые примеры в [configs/](configs/) (везде только путь к обёртке, без секретов).

**Контрольная точка 3:** после ПОЛНОГО перезапуска клиента (новая сессия) тебе доступны инструменты `meta_*`. Проверь вызовом `meta_auth_status`.

---

## Этап 4. Авторизация (OAuth) — ведёшь ты, кликает человек

1. Вызови `meta_scope_presets` и `meta_build_login_url` с пресетом **analytics** (чтение + инсайты + комментарии). Получишь login URL.
2. Скажи человеку: «Откройте эту ссылку в браузере, войдите в Facebook и разрешите доступ. Выберите ваш Instagram-аккаунт и страницу, когда спросит. **Важно:** после согласия браузер перейдёт на `localhost:8787` и покажет ошибку "не удаётся открыть страницу" — ЭТО НОРМАЛЬНО. Скопируйте ПОЛНЫЙ адрес из адресной строки этой страницы и пришлите мне».
3. Из присланного URL извлеки параметр `code` (между `code=` и `&` или концом; отбрось хвост `#_` если есть). Код одноразовый и живёт считанные минуты — не тяни.
4. Вызови `meta_exchange_code` с этим кодом → сервер сам обменяет его на long-lived токен (~60 дней) и сохранит в `~/.config/meta-instagram-mcp/token.json` (права 600).
5. Вызови `meta_resolve_instagram_account` с пустыми аргументами `{}` — сервер найдёт Instagram-аккаунт через привязанную страницу FB и сохранит его id. Если вернулась ошибка про отсутствие страниц — спроси человека, точно ли IG привязан к странице, либо возьми IG user id напрямую и вызови `meta_resolve_instagram_account {"userId": "<id>"}`.
6. **Финальная проверка:** вызови `meta_get_account_info` и покажи человеку имя аккаунта, число подписчиков. Затем `meta_list_media` с limit 3 — покажи последние посты. Поздравь человека: всё работает.

**Контрольная точка 4:** `meta_auth_status` показывает `storedToken` с `expiresAt` в будущем и `userId`.

---

## Этап 5. Что рассказать человеку после подключения

1. **Примеры запросов:** «покажи статистику последнего поста», «какие 5 постов за месяц собрали больше всего вовлечённости», «сделай сводку новых комментариев», «сравни охваты за эту и прошлую неделю».
2. **Токен живёт ~60 дней.** Предложи человеку: «раз в месяц говорите мне "обнови токен Instagram" — я вызову `meta_refresh_token`». Доктор предупреждает, когда осталось ≤10 дней.
3. **Безопасность:** файлы `instagram.env` и `token.json` — ключи от аккаунта, никому не отправлять ([docs/SECURITY.md](docs/SECURITY.md)). Отозвать доступ мгновенно: Instagram → Настройки → Безопасность → Приложения и сайты, или удалить приложение на developers.facebook.com.

---

## Типовые ошибки — что делать тебе

| Симптом | Причина и действие |
|---------|--------------------|
| В login URL человек видит «URL заблокирован / redirect_uri не разрешён» | Шаг 1.5 не сделан или URI отличается. Сверь ПОБУКВЕННО `http://localhost:8787/callback` в Facebook Login → Settings и в `instagram.env`. |
| `meta_exchange_code` → «code has expired / already used» | Код протух или вставлен повторно. Построй новый login URL (`meta_build_login_url` c `forceReauth: true`) и повтори быстро. |
| `meta_resolve_instagram_account {}` → пустой список страниц | Человек не выдал галочку страницы на consent-экране, или IG не привязан к странице. Повтори OAuth с `forceReauth: true` и скажи человеку отметить страницу; либо направь по «прямому» пути с userId. |
| `meta_get_user_insights` → ошибка/пусто | Инсайты доступны только профессиональным аккаунтам; у совсем свежих/маленьких аккаунтов часть метрик пуста — это норма Meta. |
| «Invalid platform app» / «App not active» | Приложение выключено или человек вошёл не под тем аккаунтом FB, который админ приложения. |
| Токен истёк (401 / expired) | Вызови `meta_refresh_token`. Если и он не помог (>60 дней прошло) — повтори этап 4. |
| Инструменты `meta_*` не появились | Клиент не перезапущен полностью, или конфиг указывает не на ту обёртку. Прогони доктора из контрольной точки 0. |

## Режим instagram (альтернатива без страницы Facebook)

Если у человека нет и не будет страницы FB: на шаге создания приложения выбирается сценарий **Instagram** → «API setup with Instagram login». Там свои **Instagram App ID / App Secret** (раздел Instagram → API setup with Instagram login → Business login settings; redirect URI прописывается там же). В `instagram.env` тогда: `META_AUTH_MODE=instagram` и соответствующие ID/Secret. Пресеты прав (`instagram_business_basic` и т.д.) сервер подставит сам. Остальные этапы не меняются.

## Правила для тебя, агент

1. **Никогда** не проси человека прислать пароль от Facebook/Instagram — тебе нужны только App ID, App Secret и одноразовый code.
2. **Никогда** не выводи содержимое `instagram.env` и `token.json` в чат целиком; `meta_auth_status` уже отдаёт токен в замаскированном виде — этого достаточно.
3. Это **read-only** сервер: не обещай человеку публикацию постов или ответы на комментарии — этого здесь нет (сознательно).
4. Соблюдай лимиты: не выкачивай сотни постов без нужды, Meta режет частые запросы (error 4 / 17 / 32 — подожди и повтори реже).
5. После каждого этапа фиксируй контрольную точку. Если застрял — [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
