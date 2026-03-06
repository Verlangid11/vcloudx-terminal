#!/bin/bash

NODE_DIR="/home/container/node"
BUN_DIR="/usr/local/bun"
GO_DIR="/usr/local/go"
export PLAYWRIGHT_BROWSERS_PATH="/usr/local/share/playwright"

mkdir -p "$NODE_DIR"
export PATH="$NODE_DIR/bin:$BUN_DIR/bin:$GO_DIR/bin:$HOME/.cargo/bin:$PATH"

{
echo "export PATH=\"$NODE_DIR/bin:$BUN_DIR/bin:$GO_DIR/bin:\$PATH\""
echo "export NODE_PATH=\"$NODE_DIR/lib/node_modules\""
echo "export PLAYWRIGHT_BROWSERS_PATH=\"$PLAYWRIGHT_BROWSERS_PATH\""
echo "export BUN_INSTALL=\"/usr/local/bun\""
} > /home/container/.bashrc

switch_php() {
    local target="$1"
    [ -z "$target" ] && return
    local best=""
    for v in 7.4 8.0 8.1 8.2 8.3 8.4; do
        [[ "$target" == "$v" || "$target" == "php${v}" ]] && best="$v" && break
    done
    [ -z "$best" ] && best="8.3"
    if command -v php${best} &>/dev/null; then
        sudo update-alternatives --set php /usr/bin/php${best} 2>/dev/null || \
        ln -sf /usr/bin/php${best} /usr/local/bin/php 2>/dev/null || true
    fi
}

switch_python() {
    local target="$1"
    [ -z "$target" ] && return
    local best="3.13"
    for v in 3.9 3.10 3.11 3.12 3.13; do
        [[ "$target" == "$v" ]] && best="$v" && break
    done
    command -v python${best} &>/dev/null && \
        sudo ln -sf "$(command -v python${best})" /usr/local/bin/python3 2>/dev/null || true
}

switch_go() {
    local target="$1"
    [ -z "$target" ] && return
    local current
    current=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
    [[ "$current" == ${target}* ]] && return
    local full=""
    for v in 1.21.0 1.22.0 1.23.0 1.24.0; do
        [[ "$v" == ${target}* ]] && full="$v" && break
    done
    [ -z "$full" ] && return
    wget -q "https://go.dev/dl/go${full}.linux-amd64.tar.gz" -O /tmp/go.tar.gz 2>/dev/null \
        && sudo rm -rf /usr/local/go \
        && sudo tar -C /usr/local -xzf /tmp/go.tar.gz \
        && rm /tmp/go.tar.gz || true
}

[ ! -z "${PHP_VERSION}" ]    && switch_php    "${PHP_VERSION}"
[ ! -z "${PYTHON_VERSION}" ] && switch_python "${PYTHON_VERSION}"
[ ! -z "${GO_VERSION}" ]     && switch_go     "${GO_VERSION}"

if [ ! -z "${NODE_VERSION}" ]; then
    [ -x "$NODE_DIR/bin/node" ] && CURRENT_VER=$("$NODE_DIR/bin/node" -v 2>/dev/null) || CURRENT_VER="none"
    TARGET_VER=$(curl -s https://nodejs.org/dist/index.json 2>/dev/null \
        | jq -r 'map(select(.version)) | .[] | select(.version | startswith("v'${NODE_VERSION}'")) | .version' 2>/dev/null \
        | head -n 1)
    [ -z "$TARGET_VER" ] || [ "$TARGET_VER" == "null" ] && {
        [[ "${NODE_VERSION}" == v* ]] && TARGET_VER="${NODE_VERSION}" || TARGET_VER="v${NODE_VERSION}.0.0"
    }
    if [[ "$CURRENT_VER" != "$TARGET_VER" ]]; then
        rm -rf $NODE_DIR/*
        curl -fL "https://nodejs.org/dist/${TARGET_VER}/node-${TARGET_VER}-linux-x64.tar.gz" -o /tmp/node.tar.gz 2>/dev/null
        tar -xf /tmp/node.tar.gz --strip-components=1 -C "$NODE_DIR" && rm /tmp/node.tar.gz
        "$NODE_DIR/bin/npm" install -g npm@latest pm2 pnpm yarn nodemon playwright typescript ts-node --loglevel=error 2>/dev/null
    fi
fi

if [[ "${ENABLE_CF_TUNNEL}" == "true" ]] || [[ "${ENABLE_CF_TUNNEL}" == "1" ]]; then
    [ ! -z "${CF_TOKEN}" ] && {
        pkill -f cloudflared 2>/dev/null
        nohup cloudflared tunnel run --token ${CF_TOKEN} > /home/container/.cloudflared.log 2>&1 &
        sleep 2
    }
fi

clear

P="\e[0;35m"
PB="\e[1;35m"
BB="\e[1;34m"
C="\e[1;36m"
W="\e[1;37m"
G="\e[1;32m"
Y="\e[1;33m"
R="\e[1;31m"
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

echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}            ✦  VCLOUDX MULTI-RUNTIME TERMINAL  ✦${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
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

echo -e "${BB}╔═══════════════════════════════════════════════════════════════╗${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Location ${DIM}│${RS} ${C}${CITY}, ${LOCATION}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}IP       ${DIM}│${RS} ${C}${IP}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}OS       ${DIM}│${RS} ${C}${OS}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Kernel   ${DIM}│${RS} ${C}${KERNEL}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}CPU      ${DIM}│${RS} ${C}${CPU_MODEL}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Cores    ${DIM}│${RS} ${C}${CPU_CORES} cores @ ${CPU_FREQ}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Load     ${DIM}│${RS} ${C}${LOAD_AVG}${RS}"
echo -e "${BB}║${RS}  ${P}❯${RS} ${W}Uptime   ${DIM}│${RS} ${C}${UPTIME_VAL}${RS}"
echo -e "${BB}╚═══════════════════════════════════════════════════════════════╝${RS}"
echo ""

RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_PCT=$(free -m | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}')
RAM_FREE=$(free -m | awk '/Mem:/ {print $7}')
SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
[ "$SWAP_TOTAL" -gt 0 ] \
    && SWAP_PCT=$(free -m | awk '/Swap:/ {printf "%.1f", ($3/$2)*100}') \
    || SWAP_PCT="0.0"
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
NET_RX=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null \
    | awk '{printf "%.2f MB", $1/1024/1024}' || echo "0 MB")
NET_TX=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null \
    | awk '{printf "%.2f MB", $1/1024/1024}' || echo "0 MB")

echo -e "${PB}┌───────────────────────────────────────────────────────────────┐${RS}"
echo -e "${PB}│${RS}  ${W}RAM  ${DIM}│${RS} ${G}${RAM_USED}MB${RS} ${DIM}/${RS} ${C}${RAM_TOTAL}MB${RS} ${Y}(${RAM_PCT}%)${RS} ${DIM}[free: ${RAM_FREE}MB]${RS}"
echo -e "${PB}│${RS}  ${W}SWAP ${DIM}│${RS} ${G}${SWAP_USED}MB${RS} ${DIM}/${RS} ${C}${SWAP_TOTAL}MB${RS} ${Y}(${SWAP_PCT}%)${RS}"
echo -e "${PB}│${RS}  ${W}DISK ${DIM}│${RS} ${G}${DISK_USED}${RS} ${DIM}/${RS} ${C}${DISK_TOTAL}${RS} ${Y}${DISK_PCT}${RS} ${DIM}[free: ${DISK_FREE}]${RS}"
echo -e "${PB}│${RS}  ${W}NET  ${DIM}│${RS} ${C}↓ ${NET_RX}${RS} ${DIM}│${RS} ${G}↑ ${NET_TX}${RS}"
echo -e "${PB}└───────────────────────────────────────────────────────────────┘${RS}"
echo ""

echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}                  ✦  RUNTIMES  ✦${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
echo ""

rt() {
    local name="$1" cmd="$2"
    local ver
    ver=$(eval "$cmd" 2>/dev/null)
    local lbl
    lbl=$(printf "%-13s" "$name")
    if [ -z "$ver" ]; then
        echo -e "  ${P}❯${RS} ${W}${lbl}${RS} ${DIM}│${RS} ${R}✗ not installed${RS}"
    else
        echo -e "  ${P}❯${RS} ${W}${lbl}${RS} ${DIM}│${RS} ${G}✓${RS} ${C}${ver}${RS}"
    fi
}

rt "Node.js"    "node -v"
rt "Bun"        "echo v\$(bun -v)"
rt "Deno"       "deno --version | head -n1 | awk '{print \$2}'"
rt "Python"     "python3 --version | awk '{print \$2}'"
rt "Go"         "go version | awk '{print \$3}' | sed 's/go//'"
rt "Zig"        "zig version"
rt "Ruby"       "ruby -v | awk '{print \$2}'"
rt "PHP"        "php -v | head -n1 | awk '{print \$2}'"
rt "Java"       "java -version 2>&1 | head -n1 | awk -F '\"' '{print \$2}'"
rt "Playwright" "playwright --version | head -n1"

echo ""
PHP_BAR=""
for v in 7.4 8.0 8.1 8.2 8.3 8.4; do
    if command -v php${v} &>/dev/null; then
        ACTIVE=$(php -v 2>/dev/null | head -n1 | grep -o "${v}")
        [ ! -z "$ACTIVE" ] \
            && PHP_BAR+="${G}[${v}★]${RS} " \
            || PHP_BAR+="${DIM}[${v}]${RS} "
    fi
done
echo -e "  ${P}❯${RS} ${W}PHP Versions ${RS} ${DIM}│${RS} ${PHP_BAR}"
echo ""

echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}                  ✦  TOOLS  ✦${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
echo ""

rt "FFmpeg"      "ffmpeg -version 2>/dev/null | head -n1 | awk '{print \$3}'"
rt "ImageMagick" "convert -version 2>/dev/null | head -n1 | awk '{print \$3}'"
rt "PM2"         "pm2 -v"
rt "TypeScript"  "tsc -v"
rt "PNPM"        "pnpm -v"
rt "Yarn"        "yarn -v"
rt "Git"         "git --version | awk '{print \$3}'"
rt "Composer"    "composer --version 2>/dev/null | head -n1 | awk '{print \$3}'"
rt "Bundler"     "bundler -v | awk '{print \$2}'"

echo ""
pgrep -f cloudflared > /dev/null \
    && echo -e "  ${P}❯${RS} ${W}CF Tunnel    ${RS} ${DIM}│${RS} ${G}✓ active${RS}" \
    || echo -e "  ${P}❯${RS} ${W}CF Tunnel    ${RS} ${DIM}│${RS} ${R}✗ inactive${RS}"

echo ""
echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
echo -e "${PB}  ✦ VCLOUDX${RS}  ${DIM}│${RS}  ${C}t.me/vcloudx${RS}  ${DIM}│${RS}  ${C}github.com/Verlangid11/vcloudx-terminal${RS}"
echo -e "${BB}═══════════════════════════════════════════════════════════════${RS}"
echo ""

exec /bin/bash
