# Instagram MCP Starter — подключи свой Instagram к Claude

**Твой AI-агент читает статистику твоего Instagram: посты, охваты, инсайты, комментарии.** Работает через **официальный Meta Graph API** (никакого скрейпинга и риска бана), только чтение, все ключи и токены — локально на твоём компьютере.

## 🤖 Главная фишка: настройку делает твой агент, а не ты

Этот проект написан «для агента»: вся инструкция подключения — это плейбук [AGENT.md](AGENT.md), который выполняет твой Claude. Просто скажи своему Claude (лучше всего — Claude Code):

> **«Прочитай https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/AGENT.md и подключи мой Instagram по этой инструкции»**

Агент сам установит сервер, продиктует тебе, где что нажать на developers.facebook.com (5 минут кликов), проведёт авторизацию и проверит результат. От тебя — только клики в интерфейсе Meta и вход в свой аккаунт.

## Что получишь

После подключения говоришь Claude обычным языком:

- «Какие 5 постов за месяц собрали больше всего вовлечённости?»
- «Покажи охваты и подписчиков за неделю, сравни с прошлой»
- «Сделай сводку новых комментариев и предложи ответы»
- «Собери статистику последнего Reels»

Полный список из 16 инструментов: [docs/TOOLS.md](docs/TOOLS.md).

## Что понадобится

| # | Что | Зачем |
|---|-----|-------|
| 1 | Instagram **профессионального типа** (Бизнес/Автор) | личные аккаунты Meta API не обслуживает; переключение бесплатно: Instagram → Настройки → Тип аккаунта |
| 2 | Аккаунт Facebook + страница FB, привязанная к Instagram | рекомендуемый путь авторизации (есть альтернатива без страницы — агент разберётся) |
| 3 | Node.js 20+ | [nodejs.org](https://nodejs.org) — установщик поможет |
| 4 | 15 минут и ваш AI-агент | 🙂 |

## ⚠️ Безопасность — коротко

- Всё локально: сервер работает на твоём компьютере и ходит только на graph.facebook.com. Между тобой и Meta никого нет.
- **App Secret** (`~/.instagram-mcp/instagram.env`) и **токен** (`~/.config/meta-instagram-mcp/token.json`) — это ключи доступа. Не пересылать, не коммитить, не показывать на скриншотах. Подробно: [docs/SECURITY.md](docs/SECURITY.md).
- Сервер **только читает** — публиковать посты или писать комментарии он не умеет сознательно.
- Отозвать доступ мгновенно: Instagram → Настройки → Безопасность → Приложения и сайты.

## Установка без агента (руками)

<details>
<summary>Развернуть, если хочешь по старинке</summary>

1. Получи App ID / App Secret: [docs/01-meta-app.md](docs/01-meta-app.md)
2. Запусти установщик:

```bash
# macOS / Linux
bash <(curl -fsSL https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/install.sh)
```

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/alexfisenkov/instagram-mcp-starter/main/install.ps1 | iex
```

3. Пройди авторизацию: [docs/02-oauth.md](docs/02-oauth.md)
4. Проверка: попроси Claude выполнить `meta_auth_status`.

Удаление: `uninstall.sh` / `uninstall.ps1` тем же способом.

</details>

## Диагностика

```bash
# macOS / Linux
node ~/.instagram-mcp/app/doctor.mjs ~/.instagram-mcp/run.sh
```

```powershell
# Windows
node "$env:USERPROFILE\.instagram-mcp\app\doctor.mjs" cmd /c "$env:USERPROFILE\.instagram-mcp\run.cmd"
```

Доктор показывает: запустился ли сервер, настроены ли ключи, жив ли токен и сколько дней ему осталось (без вывода секретов — можно смело слать в чат поддержки). Типовые проблемы: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) · Вопросы: [docs/FAQ.md](docs/FAQ.md)

## Устройство

```
Claude (Code / Desktop / Cursor / Codex)
        │ MCP (stdio)
        ▼
~/.instagram-mcp/run.sh|run.cmd     ← обёртка: ключи из instagram.env, не из конфигов
        ▼
meta-instagram-mcp (Node.js, этот репозиторий, собирается из исходников)
        │ HTTPS
        ▼
graph.facebook.com (официальный Meta Graph API) → твой Instagram
```

Токен long-lived (~60 дней), сервер умеет продлевать его инструментом `meta_refresh_token` — агент сам предупредит.

## Лицензия

[MIT](LICENSE). Автор: [Александр Фисенков](https://github.com/alexfisenkov), проект «Ai МАСТЕРСКАЯ». Родственный проект: [telegram-mcp-starter](https://github.com/alexfisenkov/telegram-mcp-starter).
