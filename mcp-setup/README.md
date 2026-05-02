# Burp Suite MCP Server Setup

Connect Burp Suite Professional to AI clients using the [Model Context Protocol (MCP)](https://modelcontextprotocol.io).

## Prerequisites

1. **Burp Suite Professional** running with the MCP extension loaded
2. **Java** installed (`java -version` works)
3. The [PortSwigger MCP Server Extension](https://github.com/PortSwigger/mcp-server) built and loaded into Burp

## Quick Setup

```bash
chmod +x mcp-setup/setup_mcp.sh
./mcp-setup/setup_mcp.sh
```

The interactive script will:
- Clone and build the MCP extension (optional)
- Auto-detect your Java path
- Let you pick which clients to configure
- Write or merge the config for each client

## Manual Setup

### Step 1: Build the MCP Extension

```bash
git clone https://github.com/PortSwigger/mcp-server.git ~/burp-mcp-server
cd ~/burp-mcp-server
chmod +x gradlew
./gradlew embedProxyJar
```

The proxy JAR will be at `~/burp-mcp-server/build/libs/mcp-proxy-all.jar`.

### Step 2: Load the Extension in Burp Suite

1. Open Burp Suite
2. Go to **Extensions** tab
3. Click **Add** -> Extension type: **Java** -> Select `burp-mcp-all.jar` from `build/libs/`
4. The MCP tab appears - enable the server (default: `http://127.0.0.1:9876`)

### Step 3: Configure Your MCP Client

Copy the appropriate config file from this folder and place it in the correct location:

| Client | Config Location | Config File |
|--------|----------------|-------------|
| **Claude Desktop** (macOS) | `~/Library/Application Support/Claude/claude_desktop_config.json` | `claude_desktop_config.json` |
| **Claude Desktop** (Linux) | `~/.config/Claude/claude_desktop_config.json` | `claude_desktop_config.json` |
| **Claude Code / Droid** | Run: `droid mcp add burp -- java -jar /path/to/mcp-proxy-all.jar --sse-url http://127.0.0.1:9876` | CLI command |
| **Cursor** (global) | `~/.cursor/mcp.json` | `cursor_mcp.json` |
| **Cursor** (per-project) | `.cursor/mcp.json` | `cursor_mcp.json` |
| **Windsurf** | `~/.codeium/windsurf/mcp_config.json` | `windsurf_mcp_config.json` |
| **Cline** (VS Code) | VS Code `settings.json` under `cline.mcpServers` | See snippet below |
| **Continue** | `~/.continue/config.json` | `continue_config.json` |
| **Zed** | `~/.config/zed/settings.json` under `mcp_servers` | See snippet below |
| **Any SSE client** | Use URL: `http://127.0.0.1:9876` or `http://127.0.0.1:9876/sse` | N/A |

**Important**: Replace `/path/to/mcp-proxy-all.jar` with the actual path (e.g., `~/burp-mcp-server/build/libs/mcp-proxy-all.jar`) and `java` with your full Java path if needed.

### Cline (VS Code) Snippet

Add to your VS Code `settings.json`:

```json
{
  "cline.mcpServers": {
    "burp": {
      "command": "java",
      "args": ["-jar", "/path/to/mcp-proxy-all.jar", "--sse-url", "http://127.0.0.1:9876"]
    }
  }
}
```

### Zed Snippet

Add to `~/.config/zed/settings.json`:

```json
{
  "mcp_servers": {
    "burp": {
      "command": "java",
      "args": ["-jar", "/path/to/mcp-proxy-all.jar", "--sse-url", "http://127.0.0.1:9876"]
    }
  }
}
```

## Claude Code / Factory Droid

For Factory Droid, use the CLI:

```bash
# Stdio proxy method
droid mcp add burp -- java -jar ~/burp-mcp-server/build/libs/mcp-proxy-all.jar --sse-url http://127.0.0.1:9876

# Or SSE direct (if supported)
droid mcp add burp http://127.0.0.1:9876 --type http
```

## Troubleshooting

- **"Connection refused"**: Make sure Burp Suite is running with the MCP extension loaded and the server is enabled
- **MCP tools not showing**: Restart your AI client after adding the config
- **Java not found**: Replace `java` with the full path (e.g., `/usr/bin/java` or `/usr/lib/jvm/java-21-openjdk/bin/java`)
- **Port conflict**: Change the port in the Burp MCP extension settings and update all configs accordingly
