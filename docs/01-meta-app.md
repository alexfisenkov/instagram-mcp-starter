# Шаг 1. Meta-приложение: получаем App ID и App Secret (5–10 минут)

Meta (Facebook/Instagram) даёт доступ к API только через «приложение» разработчика. Оно бесплатное, создаётся один раз и работает в режиме разработки для вашего собственного аккаунта — никакой проверки бизнеса не нужно.

> Делаете с агентом по [AGENT.md](../AGENT.md)? Тогда агент продиктует вам эти же шаги по одному — эта страница нужна как справочник.

## Подготовка аккаунтов (если ещё не сделано)

1. **Instagram → профессиональный тип.** Приложение Instagram → Настройки → Тип аккаунта и инструменты → Переключиться на профессиональный аккаунт (Автор или Бизнес — любой).
2. **Страница Facebook, связанная с Instagram** (для рекомендуемого режима). Если страницы нет: facebook.com → Меню → Страницы → Создать. Затем свяжите: Instagram → Настройки → Центр аккаунтов → Добавить аккаунты, либо в настройках страницы FB → Instagram → Подключить.

## Создание приложения

1. Откройте **https://developers.facebook.com** и войдите с вашим аккаунтом Facebook.
   - Первый раз? Нажмите **Get Started / Начать**, согласитесь с условиями, подтвердите телефон — теперь вы «разработчик Meta».
2. Справа вверху **My Apps / Мои приложения** → **Create App / Создать приложение**.
3. Мастер создания:
   - Сценарий (use case): **Other / Другое** (если такого нет — ищите вариант, дающий «Business»-тип).
   - Тип приложения: **Business / Бизнес**.
   - Имя приложения: любое, например `My IG Analytics`. E-mail оставьте ваш.
   - **Create app** (попросит пароль Facebook).
4. В панели приложения добавьте продукты (**Add products**):
   - **Facebook Login** (или Facebook Login for Business) → Set up;
   - **Instagram** (может называться Instagram Graph API) → Set up; если предлагает варианты — выбирайте **API setup with Facebook login**.
5. Слева в меню: **Facebook Login → Settings**:
   - **Valid OAuth Redirect URIs** → вставьте ровно `http://localhost:8787/callback` → **Save changes**.
   - Переключатели **Client OAuth login** и **Web OAuth login** должны быть включены.
6. Слева: **App settings → Basic**:
   - Скопируйте **App ID** (число) — понадобится.
   - **App secret → Show** (пароль Facebook) — скопируйте 32-символьный секрет. Храните как пароль!
7. Режим приложения (переключатель вверху) оставьте **Development** — для доступа к собственному аккаунту этого достаточно.

## Куда вписать ключи

Установщик спросит их сам. Вручную — файл `~/.instagram-mcp/instagram.env`:

```env
META_AUTH_MODE=facebook
META_INSTAGRAM_APP_ID=ваш_app_id
META_INSTAGRAM_APP_SECRET=ваш_app_secret
META_INSTAGRAM_REDIRECT_URI=http://localhost:8787/callback
```

Права на файл: только владелец (установщик и агент делают `chmod 600` сами).

## Альтернатива: без страницы Facebook (режим instagram)

Meta также поддерживает «Instagram-логин» без страницы FB: при создании приложения выберите сценарий **Instagram** → **API setup with Instagram login**. В этом случае:

- App ID/Secret берутся в разделе **Instagram → API setup with Instagram login → Business login settings** (это ОТДЕЛЬНЫЕ Instagram App ID/Secret, не те, что в Basic!);
- redirect URI прописывается там же;
- в `instagram.env` ставьте `META_AUTH_MODE=instagram`.

Дальше всё одинаково: [02-oauth.md](02-oauth.md).

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| Не даёт создать приложение / просит бизнес-верификацию | Для Development-режима верификация не нужна. Убедитесь, что выбрали тип Business на шаге 3 и не переключали приложение в Live. |
| Не видно продукта Instagram | Прокрутите список продуктов ниже; в новых версиях консоли Instagram добавляется через «use cases» — ищите Instagram / Instagram Graph API. |
| «URL заблокирован» при авторизации позже | Redirect URI в Facebook Login → Settings не совпадает побуквенно с `http://localhost:8787/callback`. |
| Забыли App Secret | App settings → Basic → Show — он всегда доступен админу приложения. |
