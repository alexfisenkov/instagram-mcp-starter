#!/usr/bin/env node
// Доктор: подключается к Instagram MCP как настоящий клиент и показывает
// статус конфигурации/токена (без секретов — токен в ответе редактируется).
//
// Установщик кладёт копию в ~/.instagram-mcp/app/doctor.mjs.
// Использование:
//   macOS/Linux:  node ~/.instagram-mcp/app/doctor.mjs ~/.instagram-mcp/run.sh
//   Windows:      node %USERPROFILE%\.instagram-mcp\app\doctor.mjs cmd /c %USERPROFILE%\.instagram-mcp\run.cmd
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const [command, ...args] = process.argv.slice(2);
if (!command) {
  console.error("Использование: node doctor.mjs <команда-сервера> [аргументы...]");
  process.exit(2);
}

const transport = new StdioClientTransport({ command, args, env: { ...process.env } });
const client = new Client({ name: "instagram-mcp-doctor", version: "1.0.0" });
const timer = setTimeout(() => {
  console.error("✗ Сервер не ответил за 60 секунд. См. docs/TROUBLESHOOTING.md");
  process.exit(1);
}, 60000);

try {
  await client.connect(transport);
  const tools = await client.listTools();
  console.log(`✓ MCP-сервер запустился, инструментов: ${tools.tools.length}`);
  const status = await client.callTool({ name: "meta_auth_status", arguments: {} });
  const text = (status.content ?? []).map((i) => i.text ?? "").join("\n").trim();
  console.log(text);
  let parsed;
  try { parsed = JSON.parse(text); } catch { parsed = null; }
  if (parsed?.config && !parsed.config.hasAppId) {
    console.error("! Ключи Meta-приложения ещё не настроены — следующий шаг: docs/01-meta-app.md");
    process.exitCode = 1;
  } else if (parsed && !parsed.storedToken?.accessToken) {
    console.error("! Авторизация ещё не пройдена — следующий шаг: docs/02-oauth.md (или поручите агенту по AGENT.md)");
    process.exitCode = 1;
  } else if (parsed?.storedToken?.expiresAt) {
    const daysLeft = Math.floor((Date.parse(parsed.storedToken.expiresAt) - Date.now()) / 86400000);
    if (Number.isFinite(daysLeft) && daysLeft <= 10) {
      console.error(`! Токен истекает через ${daysLeft} дн. — попросите агента выполнить meta_refresh_token`);
    } else if (Number.isFinite(daysLeft)) {
      console.log(`✓ Токен действителен ещё ~${daysLeft} дн.`);
    }
  }
} catch (error) {
  console.error(`✗ Ошибка: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
} finally {
  clearTimeout(timer);
  await client.close().catch(() => {});
}
