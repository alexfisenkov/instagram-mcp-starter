#!/usr/bin/env node
// CI smoke-тест: сервер собирается, стартует и отдаёт все инструменты,
// а meta_auth_status корректно отвечает даже без настроенных ключей.
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const serverJs = join(root, "dist", "server.js");

setTimeout(() => {
  console.error("FAIL: тест не уложился в 60 секунд");
  process.exit(1);
}, 60000).unref();

const transport = new StdioClientTransport({
  command: process.execPath,
  args: [serverJs],
  // изолируем от локального .env владельца репозитория
  env: { ...process.env, HOME: process.env.CI_FAKE_HOME ?? process.env.HOME },
});
const client = new Client({ name: "ci-smoke", version: "1.0.0" });

try {
  await client.connect(transport);
  const tools = await client.listTools();
  const names = tools.tools.map((t) => t.name).sort();
  console.log(`Инструментов: ${names.length}`);
  const required = [
    "meta_auth_status",
    "meta_build_login_url",
    "meta_exchange_code",
    "meta_refresh_token",
    "meta_resolve_instagram_account",
    "meta_get_account_info",
    "meta_list_media",
    "meta_get_top_media",
    "meta_get_user_insights",
    "meta_get_post_insights",
    "meta_list_comments",
    "meta_raw_get",
  ];
  const missing = required.filter((n) => !names.includes(n));
  if (missing.length > 0) throw new Error(`Не хватает инструментов: ${missing.join(", ")}`);

  const status = await client.callTool({ name: "meta_auth_status", arguments: {} });
  const text = (status.content ?? []).map((i) => i.text ?? "").join("\n");
  JSON.parse(text); // ответ должен быть валидным JSON
  console.log("meta_auth_status: валидный JSON-ответ получен");
  console.log("SMOKE OK");
  process.exit(0);
} catch (error) {
  console.error("SMOKE FAIL:", error instanceof Error ? error.message : String(error));
  process.exit(1);
} finally {
  await client.close().catch(() => {});
}
