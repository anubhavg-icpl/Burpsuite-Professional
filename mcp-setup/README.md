# Burp Suite MCP Server Setup

Connect Burp Suite Professional to AI clients using the [Model Context Protocol (MCP)](https://modelcontextprotocol.io).

## Architecture

Two JARs from [PortSwigger/mcp-server](https://github.com/PortSwigger/mcp-server):

| JAR | Purpose | Used by |
|-----|---------|---------|
| `build/libs/burp-mcp-all.jar` | Burp Suite Java extension | Load into Burp Suite |
| `libs/mcp-proxy-all.jar` | Standalone stdio-to-SSE proxy | AI clients |

## Quick Setup

```bash
chmod +x mcp-setup/setup_mcp.sh
./mcp-setup/setup_mcp.sh
```

## Manual Setup

### Step 1: Build

```bash
git clone https://github.com/PortSwigger/mcp-server.git ~/burp-mcp-server
cd ~/burp-mcp-server && chmod +x gradlew && ./gradlew embedProxyJar
```

### Step 2: Load Extension into Burp Suite

Extensions > Add > Java > `~/burp-mcp-server/build/libs/burp-mcp-all.jar` > Enable MCP server in MCP tab

### Step 3: Configure Your AI Client

## Claude Code (Official CLI)

Claude Code uses `claude mcp add` to register MCP servers. Three scopes available:

**User scope** (all projects):

```bash
claude mcp add --transport stdio --scope user burp -- java -jar ~/burp-mcp-server/libs/mcp-proxy-all.jar --sse-url http://127.0.0.1:9876
```

**Project scope** (shared via git, creates `.mcp.json`):

```bash
claude mcp add --transport stdio --scope project burp -- java -jar ~/burp-mcp-server/libs/mcp-proxy-all.jar --sse-url http://127.0.0.1:9876
```

**Local scope** (current project only, not shared):

```bash
claude mcp add --transport stdio --scope local burp -- java -jar ~/burp-mcp-server/libs/mcp-proxy-all.jar --sse-url http://127.0.0.1:9876
```

**Or via `.mcp.json`** (project root, for team sharing):

```json
{
  "mcpServers": {
    "burp": {
      "type": "stdio",
      "command": "java",
      "args": ["-jar", "~/burp-mcp-server/libs/mcp-proxy-all.jar", "--sse-url", "http://127.0.0.1:9876"]
    }
  }
}
```

Config file locations:

| Scope | Config Location |
|-------|----------------|
| User | `~/.claude.json` (MCP servers section) |
| Project | `.mcp.json` in project root |
| Local | `~/.claude.json` (per-project entry) |

Verify: `claude mcp list`

Docs: https://code.claude.com/docs/en/mcp

## Factory Droid

Droid uses `~/.factory/mcp.json` for global config:

```bash
droid mcp add burp --type stdio -- /path/to/java -jar ~/burp-mcp-server/libs/mcp-proxy-all.jar --sse-url http://127.0.0.1:9876
```

Or manually edit `~/.factory/mcp.json`:

```json
{
  "burp": {
    "type": "stdio",
    "command": "/path/to/java",
    "args": ["-jar", "/path/to/burp-mcp-server/libs/mcp-proxy-all.jar", "--sse-url", "http://127.0.0.1:9876"]
  }
}
```

Droid auto-reloads on config changes.

Docs: https://docs.factory.ai/cli/configuration/mcp

## All Other Clients

| Client | Config Location | Template File |
|--------|----------------|---------------|
| **Claude Desktop** (macOS) | `~/Library/Application Support/Claude/claude_desktop_config.json` | `claude_desktop_config.json` |
| **Claude Desktop** (Linux) | `~/.config/Claude/claude_desktop_config.json` | `claude_desktop_config.json` |
| **Cursor** (global) | `~/.cursor/mcp.json` | `cursor_mcp.json` |
| **Cursor** (per-project) | `.cursor/mcp.json` | `cursor_mcp.json` |
| **Windsurf** | `~/.codeium/windsurf/mcp_config.json` | `windsurf_mcp_config.json` |
| **Cline** (VS Code) | VS Code `settings.json` under `cline.mcpServers` | `cline_vscode_settings.json` |
| **Continue** | `~/.continue/config.json` | `continue_config.json` |
| **Zed** | `~/.config/zed/settings.json` under `mcp_servers` | `zed_settings.json` |
| **Any SSE client** | URL: `http://127.0.0.1:9876/sse` | N/A |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Connection refused" | Burp Suite must be running with MCP extension loaded and server enabled |
| "disconnected" | Ensure you use `libs/mcp-proxy-all.jar`, NOT `build/libs/burp-mcp-all.jar` |
| "Could not find main class" | Wrong JAR -- `libs/mcp-proxy-all.jar` is for clients, `build/libs/burp-mcp-all.jar` is for Burp only |
| Tools not showing | Restart your AI client (Droid auto-reloads) |
| Java not found | Use full path: `which java` and replace `java` with the output |
| Port conflict | Change port in Burp MCP tab and update all configs |
