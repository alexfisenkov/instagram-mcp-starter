# Troubleshooting

Первое действие — доктор (вывод без секретов, можно смело слать в чат поддержки):

```bash
# macOS / Linux
node ~/.instagram-mcp/app/doctor.mjs ~/.instagram-mcp/run.sh
```

```powershell
# Windows
node "$env:USERPROFILE\.instagram-mcp\app\doctor.mjs" cmd /c "$env:USERPROFILE\.instagram-mcp\run.cmd"
```

## Установка

### node: command not found / «не является командой»

Установите Node.js LTS с [nodejs.org](https://nodejs.org) (или дайте установщику сделать это автоматически) и откройте терминал заново. Нужен Node **20+** (`node -v`).

### npm install / npm run build падает

- Проверьте интернет; при корпоративном VPN попробуйте без него.
- Не используйте `sudo` — всё ставится в вашу домашнюю папку.
- Пришлите в чат поддержки последние 20 строк вывода.

## Подключение к Claude

### Инструменты meta_* не появились

1. Полностью перезапустите клиент (Claude Desktop: Cmd+Q / выход через трей; Claude Code: новая сессия, проверка `/mcp`).
2. `claude mcp list` — сервер `instagram` должен быть в списке.
3. Прогоните доктора: если он видит 16 инструментов, проблема в конфиге клиента — сверьте путь с [configs/](../configs/).

### Доктор: «Ключи Meta-приложения ещё не настроены»

Файл `~/.instagram-mcp/instagram.env` пуст или без App ID/Secret. Заполните по [01-meta-app.md](01-meta-app.md) (или поручите агенту — [AGENT.md](../AGENT.md), этап 2).

## Авторизация (OAuth)

### «URL заблокирован / Can't load URL / redirect_uri is not allowed»

Redirect URI не совпадает побуквенно. В Facebook Login → Settings → Valid OAuth Redirect URIs и в `instagram.env` должно быть ровно `http://localhost:8787/callback` (без слэша в конце, http, не https).

### После согласия — «не удаётся открыть страницу»

Это **нормально и задумано**: сервер не слушает браузер. Скопируйте полный адрес из адресной строки — в нём одноразовый `code`, который нужен агенту (или вставьте в `meta_exchange_code`).

### «code has expired / code has been used»

Код живёт минуты и одноразовый. Постройте новую ссылку (`meta_build_login_url`, можно с `forceReauth: true`) и повторите без пауз.

### meta_resolve_instagram_account: пустой список страниц

- На экране согласия не отмечена страница → повторите вход с `forceReauth: true` и отметьте её.
- Instagram не привязан к странице FB → привяжите ([01-meta-app.md](01-meta-app.md), «Подготовка аккаунтов») или используйте прямой путь: `meta_resolve_instagram_account {"userId": "<ваш IG user id>"}`.

### «Invalid platform app» / «App not active»

Вы входите не тем аккаунтом Facebook (нужен админ приложения) или приложение переведено в Live-режим без верификации — верните Development.

## Работа

### Ошибка «(#190) … token expired / invalid»

Токен истёк (60 дней) или был отозван. Скажите агенту «обнови токен» (`meta_refresh_token`); если не помогает — повторите OAuth ([02-oauth.md](02-oauth.md)).

### Ошибка с кодом 4 / 17 / 32 (rate limit)

Слишком много запросов подряд — лимиты Meta. Подождите 15–60 минут и просите агента запрашивать меньше данных за раз.

### Инсайты пустые или часть метрик отсутствует

Ограничение Meta: у новых/маленьких аккаунтов и у отдельных типов контента часть метрик не отдаётся. Это не ошибка установки.

### Токен «слетает» каждые пару месяцев

Так устроен Meta API: long-lived токен живёт ~60 дней. Продлевайте раз в месяц (`meta_refresh_token`) — агент и доктор напоминают.

## Ничего не помогло

Соберите и пришлите: вашу ОС, `node -v`, полный вывод доктора и что именно делали. **Не присылайте** `instagram.env`, `token.json` и App Secret.
