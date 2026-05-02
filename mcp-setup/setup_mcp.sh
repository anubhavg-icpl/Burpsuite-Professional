#!/bin/bash

# =============================================================================
# setup_mcp.sh - Configure Burp Suite MCP Server for all AI clients
#
# Supports:
#   1) Claude Code (official CLI) -- claude mcp add
#   2) Factory Droid               -- droid mcp add / ~/.factory/mcp.json
#   3) Claude Desktop              -- claude_desktop_config.json
#   4) Cursor                      -- ~/.cursor/mcp.json
#   5) Windsurf                    -- ~/.codeium/windsurf/mcp_config.json
#   6) Cline (VS Code)             -- settings.json
#   7) Continue                    -- ~/.continue/config.json
#   8) Zed                         -- settings.json
#   9) Direct SSE                  -- any compatible client
# =============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MCP_SERVER_URL="http://127.0.0.1:9876"
MCP_REPO_DIR="$HOME/burp-mcp-server"
BURP_EXTENSION_JAR=""
PROXY_JAR=""
JAVA_PATH=""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Burp Suite MCP Server Setup${NC}"
echo -e "${BLUE}  for all AI clients${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

detect_java() {
    if command -v java &> /dev/null; then
        JAVA_PATH="$(command -v java)"
        JAVA_PATH="$(readlink -f "$JAVA_PATH" 2>/dev/null || echo "$JAVA_PATH")"
        echo -e "${GREEN}[+] Java found: $JAVA_PATH${NC}"
        echo -e "    $(java -version 2>&1 | head -1)${NC}"
    else
        echo -e "${RED}Error: Java not found. Install JDK/JRE first.${NC}"
        exit 1
    fi
}

build_mcp() {
    echo ""
    echo -e "${YELLOW}[*] Cloning and building PortSwigger MCP Server...${NC}"
    if [ ! -d "$MCP_REPO_DIR" ]; then
        git clone https://github.com/PortSwigger/mcp-server.git "$MCP_REPO_DIR"
    else
        echo -e "${GREEN}[+] Repo already cloned at $MCP_REPO_DIR${NC}"
    fi
    cd "$MCP_REPO_DIR"
    chmod +x gradlew
    echo -e "${YELLOW}[*] Building (./gradlew embedProxyJar)...${NC}"
    ./gradlew embedProxyJar
    BURP_EXTENSION_JAR="$MCP_REPO_DIR/build/libs/burp-mcp-all.jar"
    PROXY_JAR="$MCP_REPO_DIR/libs/mcp-proxy-all.jar"
    if [ ! -f "$PROXY_JAR" ]; then
        echo -e "${RED}Error: Proxy JAR not found at $PROXY_JAR${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Build complete.${NC}"
    echo -e "    Burp extension: $BURP_EXTENSION_JAR"
    echo -e "    Stdio proxy:    $PROXY_JAR"
}

verify_proxy_jar() {
    if [ -z "$PROXY_JAR" ] || [ ! -f "$PROXY_JAR" ]; then
        echo -e "${RED}Error: No proxy JAR available.${NC}"
        return 1
    fi
    echo -e "${GREEN}[+] Proxy JAR: $PROXY_JAR${NC}"
}

# --- Helper: merge burp entry into a JSON config file ---
merge_config() {
    local CONFIG_FILE="$1"
    if [ -f "$CONFIG_FILE" ] && grep -q '"burp"' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}[+] Burp MCP entry already exists in $CONFIG_FILE${NC}"
        return 0
    fi
    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "burp": {
      "command": "$JAVA_PATH",
      "args": ["-jar", "$PROXY_JAR", "--sse-url", "$MCP_SERVER_URL"]
    }
  }
}
EOF
    else
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo -e "${YELLOW}[*] Merging into existing config...${NC}"
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
if "mcpServers" not in config:
    config["mcpServers"] = {}
config["mcpServers"]["burp"] = {
    "command": "$JAVA_PATH",
    "args": ["-jar", "$PROXY_JAR", "--sse-url", "$MCP_SERVER_URL"]
}
with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
PYEOF
    fi
    echo -e "${GREEN}[+] Config updated: $CONFIG_FILE${NC}"
}

# =============================================================================
# Client setup functions
# =============================================================================

setup_claude_code() {
    echo ""
    echo -e "${YELLOW}=== Claude Code (Official CLI) ===${NC}"
    echo ""
    echo -e "  Claude Code uses the ${GREEN}claude mcp add${NC} command."
    echo ""
    echo -e "  ${BLUE}User scope${NC} (all projects):"
    echo -e "  ${GREEN}claude mcp add --transport stdio --scope user burp -- $JAVA_PATH -jar $PROXY_JAR --sse-url $MCP_SERVER_URL${NC}"
    echo ""
    echo -e "  ${BLUE}Project scope${NC} (creates .mcp.json, shared via git):"
    echo -e "  ${GREEN}claude mcp add --transport stdio --scope project burp -- $JAVA_PATH -jar $PROXY_JAR --sse-url $MCP_SERVER_URL${NC}"
    echo ""
    echo -e "  ${BLUE}Local scope${NC} (current project only):"
    echo -e "  ${GREEN}claude mcp add --transport stdio --scope local burp -- $JAVA_PATH -jar $PROXY_JAR --sse-url $MCP_SERVER_URL${NC}"
    echo ""
    echo -e "  Verify: ${GREEN}claude mcp list${NC}"
    echo ""
    echo -e "  Config locations:"
    echo -e "    User/local:  ${BLUE}~/.claude.json${NC}"
    echo -e "    Project:     ${BLUE}.mcp.json${NC} in project root"
}

setup_droid() {
    echo ""
    echo -e "${YELLOW}=== Factory Droid ===${NC}"
    local CONFIG_FILE="$HOME/.factory/mcp.json"
    merge_config "$CONFIG_FILE"
    echo -e "  ${BLUE}Droid auto-reloads on config changes.${NC}"
}

setup_claude_desktop() {
    echo ""
    echo -e "${YELLOW}=== Claude Desktop ===${NC}"
    local CONFIG_FILE
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    else
        CONFIG_FILE="$HOME/.config/Claude/claude_desktop_config.json"
    fi
    merge_config "$CONFIG_FILE"
    echo -e "  ${BLUE}Restart Claude Desktop to pick up changes.${NC}"
}

setup_cursor() {
    echo ""
    echo -e "${YELLOW}=== Cursor ===${NC}"
    local CONFIG_FILE="$HOME/.cursor/mcp.json"
    merge_config "$CONFIG_FILE"
    echo -e "  ${BLUE}For per-project: create .cursor/mcp.json in your project root.${NC}"
}

setup_windsurf() {
    echo ""
    echo -e "${YELLOW}=== Windsurf ===${NC}"
    local CONFIG_FILE="$HOME/.codeium/windsurf/mcp_config.json"
    merge_config "$CONFIG_FILE"
}

setup_cline() {
    echo ""
    echo -e "${YELLOW}=== Cline (VS Code Extension) ===${NC}"
    local CONFIG_FILE
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CONFIG_FILE="$HOME/Library/Application Support/Code/User/settings.json"
    else
        CONFIG_FILE="$HOME/.config/Code/User/settings.json"
    fi
    echo ""
    echo -e "${YELLOW}Add this to VS Code settings.json (Ctrl+Shift+P > 'Open User Settings (JSON)'):${NC}"
    echo ""
    echo -e "  ${GREEN}\"cline.mcpServers\": {${NC}"
    echo -e "  ${GREEN}  \"burp\": {${NC}"
    echo -e "  ${GREEN}    \"command\": \"$JAVA_PATH\",${NC}"
    echo -e "  ${GREEN}    \"args\": [\"-jar\", \"$PROXY_JAR\", \"--sse-url\", \"$MCP_SERVER_URL\"]${NC}"
    echo -e "  ${GREEN}  }${NC}"
    echo -e "  ${GREEN}}${NC}"
    echo ""
    echo -e "  Config file: ${BLUE}$CONFIG_FILE${NC}"
}

setup_continue() {
    echo ""
    echo -e "${YELLOW}=== Continue ===${NC}"
    local CONFIG_FILE="$HOME/.continue/config.json"
    merge_config "$CONFIG_FILE"
}

setup_zed() {
    echo ""
    echo -e "${YELLOW}=== Zed ===${NC}"
    local CONFIG_FILE="$HOME/.config/zed/settings.json"
    echo ""
    echo -e "${YELLOW}Add this to $CONFIG_FILE under the existing JSON:${NC}"
    echo ""
    echo -e "  ${GREEN}\"mcp_servers\": {${NC}"
    echo -e "  ${GREEN}  \"burp\": {${NC}"
    echo -e "  ${GREEN}    \"command\": \"$JAVA_PATH\",${NC}"
    echo -e "  ${GREEN}    \"args\": [\"-jar\", \"$PROXY_JAR\", \"--sse-url\", \"$MCP_SERVER_URL\"]${NC}"
    echo -e "  ${GREEN}  }${NC}"
    echo -e "  ${GREEN}}${NC}"
}

setup_sse_direct() {
    echo ""
    echo -e "${YELLOW}=== Direct SSE (any compatible client) ===${NC}"
    echo ""
    echo "For clients that support SSE/HTTP MCP servers directly:"
    echo ""
    echo -e "  ${GREEN}SSE URL:       $MCP_SERVER_URL/sse${NC}"
    echo -e "  ${GREEN}Streamable:    $MCP_SERVER_URL/mcp${NC}"
    echo ""
    echo "Claude Code (HTTP transport):"
    echo -e "  ${GREEN}claude mcp add --transport http burp $MCP_SERVER_URL${NC}"
    echo ""
    echo "Factory Droid (HTTP type):"
    echo -e "  ${GREEN}droid mcp add burp $MCP_SERVER_URL --type http${NC}"
}

# =============================================================================
# Main
# =============================================================================

detect_java

# Step 1: Build or locate proxy JAR
echo ""
if [ -f "$MCP_REPO_DIR/libs/mcp-proxy-all.jar" ]; then
    PROXY_JAR="$MCP_REPO_DIR/libs/mcp-proxy-all.jar"
    BURP_EXTENSION_JAR="$MCP_REPO_DIR/build/libs/burp-mcp-all.jar"
    echo -e "${GREEN}[+] Proxy JAR found: $PROXY_JAR${NC}"
else
    build_mcp
fi
verify_proxy_jar

# Step 2: Remind about Burp extension
echo ""
echo -e "${YELLOW}=== Burp Suite Extension ===${NC}"
if [ -f "$BURP_EXTENSION_JAR" ]; then
    echo -e "  Load this JAR into Burp Suite as a Java extension:"
    echo -e "  ${GREEN}$BURP_EXTENSION_JAR${NC}"
else
    echo -e "  ${YELLOW}Build it: cd $MCP_REPO_DIR && ./gradlew embedProxyJar${NC}"
fi
echo -e "  Then enable the MCP server in Burp's MCP tab (default: $MCP_SERVER_URL)"

# Step 3: Pick clients
echo ""
echo -e "${BLUE}Which AI clients do you want to configure?${NC}"
echo ""
echo "  1) Claude Code          (claude mcp add --scope user/project/local)"
echo "  2) Factory Droid        (~/.factory/mcp.json)"
echo "  3) Claude Desktop       (claude_desktop_config.json)"
echo "  4) Cursor               (~/.cursor/mcp.json)"
echo "  5) Windsurf             (~/.codeium/windsurf/mcp_config.json)"
echo "  6) Cline                (VS Code settings.json)"
echo "  7) Continue             (~/.continue/config.json)"
echo "  8) Zed                  (settings.json)"
echo "  9) Direct SSE           (any compatible client)"
echo "  a) All of the above"
echo "  q) Quit"
echo ""
echo -n "Enter choices (e.g. 1 2 4 or a): "
read -r CHOICES

[ -z "$CHOICES" ] && CHOICES="q"

for choice in $CHOICES; do
    case "$choice" in
        1) setup_claude_code ;;
        2) setup_droid ;;
        3) setup_claude_desktop ;;
        4) setup_cursor ;;
        5) setup_windsurf ;;
        6) setup_cline ;;
        7) setup_continue ;;
        8) setup_zed ;;
        9) setup_sse_direct ;;
        a|A)
            setup_claude_code
            setup_droid
            setup_claude_desktop
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
echo -e "  1. Load into Burp Suite: ${BLUE}$BURP_EXTENSION_JAR${NC}"
echo -e "  2. Enable MCP server in Burp's MCP tab"
echo -e "  3. Restart your AI clients"
echo ""
