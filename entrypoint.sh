#!/bin/bash

NODE_DIR="/home/container/node"
BUN_DIR="/usr/local/bun"
GO_DIR="/usr/local/go"
export PLAYWRIGHT_BROWSERS_PATH="/usr/local/share/playwright"

mkdir -p "$NODE_DIR"
export PATH="$NODE_DIR/bin:$BUN_DIR/bin:$GO_DIR/bin:$HOME/.cargo/bin:$PATH"

echo "export PATH=\"$NODE_DIR/bin:$BUN_DIR/bin:$GO_DIR/bin:\$PATH\"" > /home/container/.bashrc
echo "export NODE_PATH=\"$NODE_DIR/lib/node_modules\"" >> /home/container/.bashrc
echo "export PLAYWRIGHT_BROWSERS_PATH=\"$PLAYWRIGHT_BROWSERS_PATH\"" >> /home/container/.bashrc

if [ ! -z "${PHP_VERSION}" ]; then
    for v in 7.4 8.0 8.1 8.2 8.3 8.4; do
        if [ "${PHP_VERSION}" == "$v" ] && command -v php${v} &>/dev/null; then
            sudo update-alternatives --set php /usr/bin/php${v} 2>/dev/null || \
            ln -sf /usr/bin/php${v} /usr/local/bin/php 2>/dev/null || true
            break
        fi
    done
fi

if [ ! -z "${NODE_VERSION}" ]; then
    [ -x "$NODE_DIR/bin/node" ] && CURRENT_VER=$("$NODE_DIR/bin/node" -v) || CURRENT_VER="none"
    TARGET_VER=$(curl -s https://nodejs.org/dist/index.json | jq -r 'map(select(.version)) | .[] | select(.version | startswith("v'${NODE_VERSION}'")) | .version' 2>/dev/null | head -n 1)

    if [ -z "$TARGET_VER" ] || [ "$TARGET_VER" == "null" ]; then
        if [[ "${NODE_VERSION}" == v* ]]; then TARGET_VER="${NODE_VERSION}"; else TARGET_VER="v${NODE_VERSION}.0.0"; fi
    fi

    if [[ "$CURRENT_VER" != "$TARGET_VER" ]]; then
        rm -rf $NODE_DIR/* && cd /tmp
        curl -fL "https://nodejs.org/dist/${TARGET_VER}/node-${TARGET_VER}-linux-x64.tar.gz" -o node.tar.gz
        tar -xf node.tar.gz --strip-components=1 -C "$NODE_DIR" && rm node.tar.gz
        "$NODE_DIR/bin/npm" install -g npm@latest pm2 pnpm yarn nodemon playwright typescript ts-node --loglevel=error
        cd /home/container
    fi
fi

if [[ "${ENABLE_CF_TUNNEL}" == "true" ]] || [[ "${ENABLE_CF_TUNNEL}" == "1" ]]; then
    if [ ! -z "${CF_TOKEN}" ]; then
        pkill -f cloudflared 2>/dev/null
        nohup cloudflared tunnel run --token ${CF_TOKEN} > /home/container/.cloudflared.log 2>&1 &
        sleep 2
    fi
fi

clear

PB="\e[1;35m"
BB="\e[1;34m"
P="\e[0;35m"
C="\e[1;36m"
G="\e[1;32m"
Y="\e[1;33m"
R="\e[1;31m"
W="\e[1;37m"
DIM="\e[2;37m"
RS="\e[0m"

echo -e "${PB}"
cat << "BANNER"
 ██╗   ██╗ ██████╗██╗      ██████╗ ██╗   ██╗██████╗ ██╗  ██╗
 ██║   ██║██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗╚██╗██╔╝
 ██║   ██║██║     ██║     ██║   ██║██║   ██║██║  ██║ ╚███╔╝ 
 ╚██╗ ██╔╝██║     ██║     ██║   ██║██║   ██║██║  ██║ ██╔██╗ 
  ╚████╔╝ ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝██╔╝ ██╗
   ╚═══╝   ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═╝
BANNER
echo -e "${RS}"

echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}              ✦  VCLOUDX MULTI-RUNTIME TERMINAL  ✦${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo ""

LOCATION=$(curl -s --max-time 3 ipinfo.io/country 2>/dev/null || echo 'Unknown')
CITY=$(curl -s --max-time 3 ipinfo.io/city 2>/dev/null || echo 'Unknown')
IP=$(curl -s --max-time 3 ipinfo.io/ip 2>/dev/null || echo 'Unknown')
OS=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')
KERNEL=$(uname -r)
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
CPU_FREQ=$(grep -m1 'cpu MHz' /proc/cpuinfo | awk '{printf "%.2f GHz", $4/1000}')
UPTIME_VAL=$(uptime -p | sed 's/up //')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)

echo -e "${BB}╔═══════════════════════════════════════════════════════════════════╗${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Location   ${DIM}│${RS} ${C}${CITY}, ${LOCATION}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}IP         ${DIM}│${RS} ${C}${IP}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}OS         ${DIM}│${RS} ${C}${OS}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Kernel     ${DIM}│${RS} ${C}${KERNEL}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}CPU        ${DIM}│${RS} ${C}${CPU_MODEL}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Cores      ${DIM}│${RS} ${C}${CPU_CORES} cores @ ${CPU_FREQ}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Load       ${DIM}│${RS} ${C}${LOAD_AVG}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Uptime     ${DIM}│${RS} ${C}${UPTIME_VAL}${RS}"
echo -e "${BB}╚═══════════════════════════════════════════════════════════════════╝${RS}"
echo ""

RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_PCT=$(free -m | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}')
RAM_FREE=$(free -m | awk '/Mem:/ {print $7}')
SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
[ "$SWAP_TOTAL" -gt 0 ] && SWAP_PCT=$(free -m | awk '/Swap:/ {printf "%.1f", ($3/$2)*100}') || SWAP_PCT="0.0"
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
INODE_USED=$(df -i / | awk 'NR==2 {print $3}')
INODE_TOTAL=$(df -i / | awk 'NR==2 {print $2}')
INODE_PCT=$(df -i / | awk 'NR==2 {print $5}')
NET_RX=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null | awk '{printf "%.2f MB", $1/1024/1024}' || echo "0 MB")
NET_TX=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null | awk '{printf "%.2f MB", $1/1024/1024}' || echo "0 MB")

echo -e "${PB}┌───────────────────────────────────────────────────────────────────┐${RS}"
echo -e "${PB}│${RS}  ${W}RAM    ${DIM}│${RS} ${G}${RAM_USED}MB${RS} ${DIM}/${RS} ${C}${RAM_TOTAL}MB${RS} ${Y}(${RAM_PCT}%)${RS} ${DIM}[free: ${RAM_FREE}MB]${RS}"
echo -e "${PB}│${RS}  ${W}SWAP   ${DIM}│${RS} ${G}${SWAP_USED}MB${RS} ${DIM}/${RS} ${C}${SWAP_TOTAL}MB${RS} ${Y}(${SWAP_PCT}%)${RS}"
echo -e "${PB}│${RS}  ${W}DISK   ${DIM}│${RS} ${G}${DISK_USED}${RS} ${DIM}/${RS} ${C}${DISK_TOTAL}${RS} ${Y}${DISK_PCT}${RS} ${DIM}[free: ${DISK_FREE}]${RS}"
echo -e "${PB}│${RS}  ${W}INODE  ${DIM}│${RS} ${G}${INODE_USED}${RS} ${DIM}/${RS} ${C}${INODE_TOTAL}${RS} ${Y}${INODE_PCT}${RS}"
echo -e "${PB}│${RS}  ${W}NET    ${DIM}│${RS} ${C}↓ ${NET_RX}${RS} ${DIM}│${RS} ${G}↑ ${NET_TX}${RS}"
echo -e "${PB}└───────────────────────────────────────────────────────────────────┘${RS}"
echo ""

echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}                    ✦  RUNTIMES  ✦${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo ""

print_runtime() {
    local name=$1
    local cmd=$2
    local version
    version=$(eval "$cmd" 2>/dev/null || echo 'Not Installed')
    local pad
    pad=$(printf '%*s' $((15-${#name})) '')
    if [[ "$version" == "Not Installed" ]]; then
        echo -e "  ${P}❯${RS} ${W}${name}${RS}${pad} ${DIM}│${RS} ${R}✗ ${version}${RS}"
    else
        echo -e "  ${P}❯${RS} ${W}${name}${RS}${pad} ${DIM}│${RS} ${G}✓${RS} ${C}${version}${RS}"
    fi
}

print_runtime "Node.js"    "node -v"
print_runtime "Bun"        "echo v\$(bun -v)"
print_runtime "Deno"       "deno --version | head -n1 | awk '{print \$2}'"
print_runtime "Python"     "python3 --version | awk '{print \$2}'"
print_runtime "Go"         "go version | awk '{print \$3}' | sed 's/go//'"
print_runtime "Zig"        "zig version"
print_runtime "Ruby"       "ruby -v | awk '{print \$2}'"
print_runtime "PHP"        "php -v | head -n1 | awk '{print \$2}'"
print_runtime "Java"       "java -version 2>&1 | head -n1 | awk -F '\"' '{print \$2}'"
print_runtime "Playwright" "playwright --version | head -n1"

echo ""
PHP_BAR=""
for v in 7.4 8.0 8.1 8.2 8.3 8.4; do
    if command -v php${v} &>/dev/null; then
        ACTIVE_PHP=$(php -v 2>/dev/null | head -n1 | grep -o "${v}")
        if [ ! -z "$ACTIVE_PHP" ]; then
            PHP_BAR+="${G}[${v}★]${RS} "
        else
            PHP_BAR+="${DIM}[${v}]${RS} "
        fi
    fi
done
echo -e "  ${P}❯${RS} ${W}PHP Versions   ${DIM}│${RS} ${PHP_BAR}"

echo ""
echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}                    ✦  TOOLS  ✦${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo ""

print_runtime "FFmpeg"      "ffmpeg -version | head -n1 | awk '{print \$3}'"
print_runtime "ImageMagick" "convert -version | head -n1 | awk '{print \$3}'"
print_runtime "WebP"        "cwebp -version 2>&1 | head -n1 | awk '{print \$2}'"
print_runtime "PM2"         "pm2 -v"
print_runtime "Nodemon"     "nodemon -v"
print_runtime "TypeScript"  "tsc -v"
print_runtime "PNPM"        "pnpm -v"
print_runtime "Yarn"        "yarn -v"
print_runtime "Git"         "git --version | awk '{print \$3}'"
print_runtime "Composer"    "composer --version 2>/dev/null | head -n1 | awk '{print \$3}'"
print_runtime "Bundler"     "bundler -v"

echo ""
if pgrep -f cloudflared > /dev/null; then
    echo -e "  ${P}❯${RS} ${W}CF Tunnel      ${DIM}│${RS} ${G}✓ Active${RS}"
else
    echo -e "  ${P}❯${RS} ${W}CF Tunnel      ${DIM}│${RS} ${R}✗ Inactive${RS}"
fi

echo ""
echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}  ✦ VCLOUDX${RS}  ${DIM}│${RS}  ${C}t.me/vcloudx${RS}  ${DIM}│${RS}  ${C}github.com/Verlangid11/vcloudx-terminal${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════════${RS}"
echo ""

exec /bin/bash
