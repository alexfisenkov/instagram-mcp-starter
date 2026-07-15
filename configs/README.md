# Примеры конфигов

Замените `ВАШЕ_ИМЯ` на имя пользователя (macOS: `echo $HOME`, Windows: `echo $env:USERPROFILE`).
Секретов в конфигах нет — только путь к обёртке; ключи живут в `~/.instagram-mcp/instagram.env`.

| Файл | Клиент | Куда |
|------|--------|------|
| `claude_desktop_macos_linux.example.json` | Claude Desktop (macOS/Linux) | `~/Library/Application Support/Claude/claude_desktop_config.json` / `~/.config/Claude/...` |
| `claude_desktop_windows.example.json` | Claude Desktop (Windows) | `%APPDATA%\Claude\claude_desktop_config.json` |
| `cursor.example.json` | Cursor (Windows: command/args как у Desktop-Windows) | `~/.cursor/mcp.json` |
| `codex.example.toml` | Codex CLI | `~/.codex/config.toml` |

Claude Code — командой: `claude mcp add instagram -s user -- "$HOME/.instagram-mcp/run.sh"`
(Windows: `claude mcp add instagram -s user -- cmd /c "%USERPROFILE%\.instagram-mcp\run.cmd"`).
