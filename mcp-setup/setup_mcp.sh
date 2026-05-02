#!/bin/bash

# =============================================================================
# setup_mcp.sh - Configure Burp Suite MCP Server for various AI clients
#
# This script builds the Burp MCP extension (if not already built),
# and sets up MCP client configuration for:
#   - Claude Desktop
#   - Claude Code (Factory Droid)
#   - Cursor
#   - Windsurf
#   - Cline (VS Code)
#   - Continue
#   - Zed
#
# Prerequisites:
#   - Java (jdk/jre) installed and in PATH
#   - Burp Suite Professional running with MCP extension loaded
#   - The MCP extension listening on http://127.0.0.1:9876 (default)
# =============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MCP_SERVER_URL="http://127.0.0.1:9876"
MCP_SERVER_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_REPO_DIR="$HOME/burp-mcp-server"
PROXY_JAR=""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Burp Suite MCP Server Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "MCP Server URL: ${GREEN}$MCP_SERVER_URL${NC}"
echo ""

# --- Step 1: Build the MCP extension (optional, if not already built) ---
build_mcp_extension() {
    if [ -f "$MCP_REPO_DIR/build/libs/burp-mcp-all.jar" ]; then
        echo -e "${GREEN}[+] MCP extension already built at $MCP_REPO_DIR/build/libs/burp-mcp-all.jar${NC}"
        PROXY_JAR="$MCP_REPO_DIR/build/libs/mcp-proxy-all.jar"
        return 0
    fi

    echo -e "${YELLOW}[*] Cloning and building Burp MCP Server extension...${NC}"
    if [ ! -d "$MCP_REPO_DIR" ]; then
        git clone https://github.com/PortSwigger/mcp-server.git "$MCP_REPO_DIR"
    fi
    cd "$MCP_REPO_DIR"
    chmod +x gradlew
    ./gradlew embedProxyJar
    echo -e "${GREEN}[+] MCP extension built successfully.${NC}"
    PROXY_JAR="$MCP_REPO_DIR/build/libs/mcp-proxy-all.jar"
}

# --- Java path detection ---
detect_java() {
    if command -v java &> /dev/null; then
        JAVA_PATH="$(which java)"
        echo -e "${GREEN}[+] Java found at: $JAVA_PATH${NC}"
    else
        echo -e "${RED}Error: Java not found. Install JDK/JRE first.${NC}"
        exit 1
    fi
}

# --- Config writers ---
setup_claude_desktop() {
    echo ""
    echo -e "${YELLOW}=== Claude Desktop ===${NC}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    else
        CONFIG_FILE="$HOME/.config/Claude/claude_desktop_config.json"
    fi

    CONFIG_DIR="$(dirname "$CONFIG_FILE")"
    mkdir -p "$CONFIG_DIR"

    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}[*] Existing config found at $CONFIG_FILE${NC}"
        echo -e "${YELLOW}[*] Backing up to ${CONFIG_FILE}.bak${NC}"
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    fi

    # Check if burp entry already exists
    if [ -f "$CONFIG_FILE" ] && grep -q '"burp"' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}[+] Burp MCP entry already exists in Claude Desktop config.${NC}"
        return 0
    fi

    # Create or merge config
    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "burp": {
      "command": "$JAVA_PATH",
      "args": [
        "-jar",
        "$PROXY_JAR",
        "--sse-url",
        "$MCP_SERVER_URL"
      ]
    }
  }
}
EOF
    else
        echo -e "${YELLOW}[*] Merging Burp MCP into existing config...${NC}"
        python3 -c "
import json, sys
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'mcpServers' not in config:
    config['mcpServers'] = {}
config['mcpServers']['burp'] = {
    'command': '$JAVA_PATH',
    'args': ['-jar', '$PROXY_JAR', '--sse-url', '$MCP_SERVER_URL']
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
"
    fi

    echo -e "${GREEN}[+] Claude Desktop config updated: $CONFIG_FILE${NC}"
    echo -e "    ${BLUE}Restart Claude Desktop to pick up the changes.${NC}"
}

setup_claude_code() {
    echo ""
    echo -e "${YELLOW}=== Claude Code / Factory Droid ===${NC}"
    echo ""
    echo "Run the following command to add the Burp MCP server:"
    echo ""
    echo -e "  ${GREEN}droid mcp add burp -- $JAVA_PATH -jar $PROXY_JAR --sse-url $MCP_SERVER_URL${NC}"
    echo ""
    echo "Or manually add to your project's .factory/mcp.json:"
    echo ""
    cat << EOF
  {
    "burp": {
      "command": "$JAVA_PATH",
      "args": ["-jar", "$PROXY_JAR", "--sse-url", "$MCP_SERVER_URL"]
    }
  }
EOF
    echo ""
    echo -e "For SSE-based connection, you can also use:"
    echo -e "  ${GREEN}droid mcp add burp $MCP_SERVER_URL --type http${NC}"
}

setup_cursor() {
    echo ""
    echo -e "${YELLOW}=== Cursor ===${NC}"

    CONFIG_FILE="$HOME/.cursor/mcp.json"
    CONFIG_DIR="$(dirname "$CONFIG_FILE")"
    mkdir -p "$CONFIG_DIR"

    if [ -f "$CONFIG_FILE" ] && grep -q '"burp"' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}[+] Burp MCP entry already exists in Cursor config.${NC}"
        return 0
    fi

    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "burp": {
      "command": "$JAVA_PATH",
      "args": [
        "-jar",
        "$PROXY_JAR",
        "--sse-url",
        "$MCP_SERVER_URL"
      ]
    }
  }
}
EOF
    else
        echo -e "${YELLOW}[*] Merging Burp MCP into existing Cursor config...${NC}"
        python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'mcpServers' not in config:
    config['mcpServers'] = {}
config['mcpServers']['burp'] = {
    'command': '$JAVA_PATH',
    'args': ['-jar', '$PROXY_JAR', '--sse-url', '$MCP_SERVER_URL']
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
"
    fi

    echo -e "${GREEN}[+] Cursor config updated: $CONFIG_FILE${NC}"
    echo -e "    ${BLUE}You can also add per-project config in .cursor/mcp.json${NC}"
}

setup_windsurf() {
    echo ""
    echo -e "${YELLOW}=== Windsurf ===${NC}"

    CONFIG_FILE="$HOME/.codeium/windsurf/mcp_config.json"
    CONFIG_DIR="$(dirname "$CONFIG_FILE")"
    mkdir -p "$CONFIG_DIR"

    if [ -f "$CONFIG_FILE" ] && grep -q '"burp"' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}[+] Burp MCP entry already exists in Windsurf config.${NC}"
        return 0
    fi

    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "burp": {
      "command": "$JAVA_PATH",
      "args": [
        "-jar",
        "$PROXY_JAR",
        "--sse-url",
        "$MCP_SERVER_URL"
      ]
    }
  }
}
EOF
    else
        echo -e "${YELLOW}[*] Merging Burp MCP into existing Windsurf config...${NC}"
        python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'mcpServers' not in config:
    config['mcpServers'] = {}
config['mcpServers']['burp'] = {
    'command': '$JAVA_PATH',
    'args': ['-jar', '$PROXY_JAR', '--sse-url', '$MCP_SERVER_URL']
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
"
    fi

    echo -e "${GREEN}[+] Windsurf config updated: $CONFIG_FILE${NC}"
}

setup_cline() {
    echo ""
    echo -e "${YELLOW}=== Cline (VS Code Extension) ===${NC}"
    echo ""
    echo "Cline reads MCP servers from VS Code's settings.json."
    echo "Add the following to your VS Code settings.json"
    echo "(open via: Ctrl+Shift+P -> 'Open User Settings (JSON)'):"
    echo ""
    cat << 'SETTINGS'
  "cline.mcpServers": {
    "burp": {
      "command": "JAVA_PATH",
      "args": ["-jar", "PROXY_JAR", "--sse-url", "http://127.0.0.1:9876"]
    }
  }
SETTINGS
    echo ""
    echo -e "Replace ${YELLOW}JAVA_PATH${NC} with: ${GREEN}$JAVA_PATH${NC}"
    echo -e "Replace ${YELLOW}PROXY_JAR${NC} with: ${GREEN}$PROXY_JAR${NC}"
}

setup_continue() {
    echo ""
    echo -e "${YELLOW}=== Continue ===${NC}"

    CONFIG_FILE="$HOME/.continue/config.json"
    CONFIG_DIR="$(dirname "$CONFIG_FILE")"
    mkdir -p "$CONFIG_DIR"

    if [ -f "$CONFIG_FILE" ] && grep -q '"burp"' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}[+] Burp MCP entry already exists in Continue config.${NC}"
        return 0
    fi

    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "burp": {
      "command": "$JAVA_PATH",
      "args": [
        "-jar",
        "$PROXY_JAR",
        "--sse-url",
        "$MCP_SERVER_URL"
      ]
    }
  }
}
EOF
    else
        echo -e "${YELLOW}[*] Merging Burp MCP into existing Continue config...${NC}"
        python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'mcpServers' not in config:
    config['mcpServers'] = {}
config['mcpServers']['burp'] = {
    'command': '$JAVA_PATH',
    'args': ['-jar', '$PROXY_JAR', '--sse-url', '$MCP_SERVER_URL']
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
"
    fi

    echo -e "${GREEN}[+] Continue config updated: $CONFIG_FILE${NC}"
}

setup_zed() {
    echo ""
    echo -e "${YELLOW}=== Zed ===${NC}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        CONFIG_FILE="$HOME/.config/zed/settings.json"
    else
        CONFIG_FILE="$HOME/.config/zed/settings.json"
    fi
    CONFIG_DIR="$(dirname "$CONFIG_FILE")"
    mkdir -p "$CONFIG_DIR"

    echo "Add the following to your Zed settings.json at $CONFIG_FILE:"
    echo ""
    cat << 'SETTINGS'
  "mcp_servers": {
    "burp": {
      "command": "JAVA_PATH",
      "args": ["-jar", "PROXY_JAR", "--sse-url", "http://127.0.0.1:9876"]
    }
  }
SETTINGS
    echo ""
    echo -e "Replace ${YELLOW}JAVA_PATH${NC} with: ${GREEN}$JAVA_PATH${NC}"
    echo -e "Replace ${YELLOW}PROXY_JAR${NC} with: ${GREEN}$PROXY_JAR${NC}"
}

# --- Direct SSE config (for clients that support it) ---
setup_sse_direct() {
    echo ""
    echo -e "${YELLOW}=== Direct SSE Connection (any SSE-compatible client) ===${NC}"
    echo ""
    echo "If your client supports SSE MCP servers directly, use this URL:"
    echo ""
    echo -e "  ${GREEN}$MCP_SERVER_URL${NC}"
    echo ""
    echo "or with the /sse path:"
    echo ""
    echo -e "  ${GREEN}$MCP_SERVER_URL/sse${NC}"
}

# =============================================================================
# Main
# =============================================================================

detect_java

echo ""
echo -e "${YELLOW}Do you want to build the MCP extension? (y/n)${NC}"
echo "  (Skip if you already have mcp-proxy-all.jar)"
read -r BUILD_CHOICE
if [[ "$BUILD_CHOICE" =~ ^[Yy]$ ]]; then
    build_mcp_extension
else
    echo -e "${YELLOW}[*] Enter path to mcp-proxy-all.jar (or press Enter to skip proxy setup):${NC} "
    read -r PROXY_JAR
    if [ -z "$PROXY_JAR" ]; then
        echo -e "${YELLOW}[*] No proxy JAR specified. Will show SSE-only configs.${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Which clients do you want to configure?${NC}"
echo ""
echo "  1) Claude Desktop"
echo "  2) Claude Code / Factory Droid"
echo "  3) Cursor"
echo "  4) Windsurf"
echo "  5) Cline (VS Code)"
echo "  6) Continue"
echo "  7) Zed"
echo "  8) Direct SSE (any client)"
echo "  a) All"
echo "  q) Quit"
echo ""
echo -n "Enter choices (e.g. 1 3 5 or a): "
read -r CHOICES

if [ -z "$CHOICES" ]; then
    CHOICES="q"
fi

for choice in $CHOICES; do
    case "$choice" in
        1) setup_claude_desktop ;;
        2) setup_claude_code ;;
        3) setup_cursor ;;
        4) setup_windsurf ;;
        5) setup_cline ;;
        6) setup_continue ;;
        7) setup_zed ;;
        8) setup_sse_direct ;;
        a|A)
            setup_claude_desktop
            setup_claude_code
            setup_cursor
            setup_windsurf
            setup_cline
            setup_continue
            setup_zed
            setup_sse_direct
            ;;
        q|Q) exit 0 ;;
        *) echo -e "${RED}Unknown option: $choice${NC}" ;;
    esac
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MCP Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Make sure Burp Suite is running with the MCP extension loaded."
echo -e "The extension should be listening on ${BLUE}$MCP_SERVER_URL${NC}"
echo ""
