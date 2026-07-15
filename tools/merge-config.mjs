#!/usr/bin/env node
// Безопасно добавляет (или удаляет) MCP-сервер в JSON-конфиг клиента
// (например, claude_desktop_config.json). Перед изменением делает резервную копию.
//
// Использование:
//   node merge-config.mjs <config.json> <имя> <command> [args...]   — добавить/обновить
//   node merge-config.mjs <config.json> <имя> --remove              — удалить
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
