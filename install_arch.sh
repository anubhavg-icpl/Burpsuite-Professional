#!/bin/bash

# =============================================================================
# install_arch.sh - Install Burp Suite Professional on Arch Linux
# Supports: Arch Linux, EndeavourOS, Manjaro, Garuda, etc.
# =============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/Burpsuite-Professional"
VERSION=2026

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Burp Suite Professional - Arch Linux${NC}"
echo -e "${BLUE}========================================${NC}"

# Check for pacman
if ! command -v pacman &> /dev/null; then
    echo -e "${RED}Error: pacman not found. This script is for Arch-based distributions.${NC}"
    exit 1
fi

# Installing Dependencies
echo -e "${YELLOW}[*] Installing dependencies...${NC}"

# Check if Java is already available (JDK includes JRE)
if command -v java &> /dev/null; then
    echo -e "${GREEN}[+] Java already installed: $(java -version 2>&1 | head -1)${NC}"
    sudo pacman -S --noconfirm --needed git wget
else
    # No Java found, install JRE (or JDK if preferred)
    sudo pacman -Syu --noconfirm --needed git wget jre-openjdk
fi

# Verify Java is available
if ! command -v java &> /dev/null; then
    echo -e "${RED}Error: Java not found. Please install jre-openjdk or jdk-openjdk manually.${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Dependencies installed successfully.${NC}"

# Cloning
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}[*] Updating existing installation at $INSTALL_DIR...${NC}"
    cd "$INSTALL_DIR"
    git pull || true
else
    echo -e "${YELLOW}[*] Cloning repository...${NC}"
    sudo git clone https://github.com/xiv3r/Burpsuite-Professional.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

sudo chown -R "$USER":"$USER" "$INSTALL_DIR"

# Download Burpsuite Professional
echo -e "${YELLOW}[*] Downloading Burp Suite Professional v$VERSION...${NC}"
wget -O burpsuite_pro_v$VERSION.jar https://github.com/xiv3r/Burpsuite-Professional/releases/download/burpsuite-pro/burpsuite_pro_v$VERSION.jar

if [ ! -f "burpsuite_pro_v$VERSION.jar" ]; then
    echo -e "${RED}Error: Failed to download Burp Suite Professional.${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Burp Suite Professional downloaded.${NC}"

# Create launcher script
echo -e "${YELLOW}[*] Creating launcher command...${NC}"
LAUNCHER_PATH="/usr/local/bin/burpsuitepro"

cat > "$INSTALL_DIR/burpsuitepro" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
java --add-opens=java.desktop/javax.swing=ALL-UNNAMED \
     --add-opens=java.base/java.lang=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED \
     -javaagent:$INSTALL_DIR/loader.jar \
     -noverify \
     -jar $INSTALL_DIR/burpsuite_pro_v$VERSION.jar
EOF

chmod +x "$INSTALL_DIR/burpsuitepro"
sudo cp "$INSTALL_DIR/burpsuitepro" "$LAUNCHER_PATH"
sudo chmod +x "$LAUNCHER_PATH"

echo -e "${GREEN}[+] Launcher installed to $LAUNCHER_PATH${NC}"

# Create a .desktop file for application menu integration
echo -e "${YELLOW}[*] Creating desktop entry...${NC}"
DESKTOP_FILE="/usr/share/applications/burpsuitepro.desktop"

cat << DESKTOP | sudo tee "$DESKTOP_FILE" > /dev/null
[Desktop Entry]
Name=Burp Suite Professional
Comment=Web application security testing tool
Exec=$LAUNCHER_PATH
Icon=$INSTALL_DIR/burp_suite.ico
Terminal=false
Type=Application
Categories=Development;Security;System;
DESKTOP

echo -e "${GREEN}[+] Desktop entry created.${NC}"

# Start the loader keygen
echo -e "${YELLOW}[*] Starting Key Generator (loader.jar)...${NC}"
(java -jar "$INSTALL_DIR/loader.jar") &

# Start Burp Suite Professional
echo -e "${YELLOW}[*] Starting Burp Suite Professional...${NC}"
"$LAUNCHER_PATH" &

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Run anytime with:  ${BLUE}burpsuitepro${NC}"
echo ""
echo -e "  ${YELLOW}License Activation:${NC}"
echo -e "  1. Copy the license from the loader window"
echo -e "  2. Paste into Burp Suite > Manual Activation"
echo -e "  3. Copy Burp's request key into the loader"
echo -e "  4. Copy the loader's response key into Burp"
echo ""
