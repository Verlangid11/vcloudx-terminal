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
echo "export BUN_INSTALL=\"/usr/local/bun\"" >> /home/container/.bashrc

switch_php_version() {
    local target="$1"
    if [ -z "$target" ]; then return; fi

    local available_versions=("7.4" "8.0" "8.1" "8.2" "8.3" "8.4")
    local matched=""

    for v in "${available_versions[@]}"; do
        if [[ "$target" == "$v" ]] || [[ "$target" == "php${v}" ]]; then
            matched="$v"
            break
        fi
    done

    if [ -z "$matched" ]; then
        for v in "${available_versions[@]}"; do
            if [[ "$v" == ${target}* ]]; then
                matched="$v"
                break
            fi
        done
    fi

    if [ -z "$matched" ]; then
        matched="8.3"
    fi

    if command -v php${matched} &>/dev/null; then
        sudo update-alternatives --set php /usr/bin/php${matched} 2>/dev/null || \
            ln -sf /usr/bin/php${matched} /usr/local/bin/php 2>/dev/null || true
    fi
}

if [ ! -z "${PHP_VERSION}" ]; then
    switch_php_version "${PHP_VERSION}"
fi

switch_python_version() {
    local target="$1"
    if [ -z "$target" ]; then return; fi

    local available_versions=("3.9" "3.10" "3.11" "3.12" "3.13")
    local matched=""

    for v in "${available_versions[@]}"; do
        if [[ "$target" == "$v" ]] || [[ "$target" == "python${v}" ]]; then
            matched="$v"
            break
        fi
    done

    if [ -z "$matched" ]; then
        matched="3.13"
    fi

    if command -v python${matched} &>/dev/null; then
        sudo ln -sf $(command -v python${matched}) /usr/local/bin/python3 2>/dev/null || true
    fi
}

if [ ! -z "${PYTHON_VERSION}" ]; then
    switch_python_version "${PYTHON_VERSION}"
fi

switch_go_version() {
    local target="$1"
    if [ -z "$target" ]; then return; fi

    local available_versions=("1.21.0" "1.22.0" "1.23.0" "1.24.0")
    local matched=""

    for v in "${available_versions[@]}"; do
        if [[ "$v" == ${target}* ]]; then
            matched="$v"
            break
        fi
    done

    if [ -z "$matched" ] || ! [ -d "/usr/local/go" ]; then
        return
    fi

    if [ "$matched" != "$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')" ]; then
        wget -q "https://go.dev/dl/go${matched}.linux-amd64.tar.gz" -O /tmp/go.tar.gz 2>/dev/null \
            && sudo rm -rf /usr/local/go \
            && sudo tar -C /usr/local -xzf /tmp/go.tar.gz \
            && rm /tmp/go.tar.gz \
            || true
    fi
}

if [ ! -z "${GO_VERSION}" ]; then
    switch_go_version "${GO_VERSION}"
fi

if [ ! -z "${NODE_VERSION}" ]; then
    [ -x "$NODE_DIR/bin/node" ] && CURRENT_VER=$("$NODE_DIR/bin/node" -v 2>/dev/null) || CURRENT_VER="none"
    TARGET_VER=$(curl -s https://nodejs.org/dist/index.json 2>/dev/null | jq -r 'map(select(.version)) | .[] | select(.version | startswith("v'${NODE_VERSION}'")) | .version' 2>/dev/null | head -n 1)

    if [ -z "$TARGET_VER" ] || [ "$TARGET_VER" == "null" ]; then
        if [[ "${NODE_VERSION}" == v* ]]; then TARGET_VER="${NODE_VERSION}"; else TARGET_VER="v${NODE_VERSION}.0.0"; fi
    fi

    if [[ "$CURRENT_VER" != "$TARGET_VER" ]]; then
        rm -rf $NODE_DIR/*
        curl -fL "https://nodejs.org/dist/${TARGET_VER}/node-${TARGET_VER}-linux-x64.tar.gz" -o /tmp/node.tar.gz 2>/dev/null
        tar -xf /tmp/node.tar.gz --strip-components=1 -C "$NODE_DIR" && rm /tmp/node.tar.gz
        "$NODE_DIR/bin/npm" install -g npm@latest pm2 pnpm yarn nodemon playwright typescript ts-node --loglevel=error 2>/dev/null
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

P="\e[0;35m"
B="\e[0;34m"
PB="\e[1;35m"
BB="\e[1;34m"
C="\e[1;36m"
W="\e[1;37m"
G="\e[1;32m"
Y="\e[1;33m"
R="\e[1;31m"
DIM="\e[2;37m"
RESET="\e[0m"

echo -e "${PB}"
cat << "EOF"
 ██╗   ██╗███████╗██████╗ ██╗      █████╗ ███╗   ██╗ ██████╗ ██╗██████╗ 
 ██║   ██║██╔════╝██╔══██╗██║     ██╔══██╗████╗  ██║██╔════╝ ██║██╔══██╗
 ██║   ██║█████╗  ██████╔╝██║     ███████║██╔██╗ ██║██║  ███╗██║██║  ██║
 ╚██╗ ██╔╝██╔══╝  ██╔══██╗██║     ██╔══██║██║╚██╗██║██║   ██║██║██║  ██║
  ╚████╔╝ ███████╗██║  ██║███████╗██║  ██║██║ ╚████║╚██████╔╝██║██████╔╝
   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═════╝
EOF
echo -e "${RESET}"

echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${PB}              ✦  MULTI-RUNTIME TERMINAL  ✦${RESET}"
echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo ""

LOCATION=$(curl -s --max-time 3 ipinfo.io/country 2>/dev/null || echo 'Unknown')
CITY=$(curl -s --max-time 3 ipinfo.io/city 2>/dev/null || echo 'Unknown')
IP=$(curl -s --max-time 3 ipinfo.io/ip 2>/dev/null || echo 'Unknown')
OS=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')
KERNEL=$(uname -r)
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
CPU_FREQ=$(grep -m1 'cpu MHz' /proc/cpuinfo | awk '{printf "%.2f GHz", $4/1000}')
UPTIME=$(uptime -p | sed 's/up //')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)

echo -e "${BB}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}Location   ${RESET}${DIM}│${RESET}  ${C}${CITY}, ${LOCATION}${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}IP         ${RESET}${DIM}│${RESET}  ${C}${IP}${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}OS         ${RESET}${DIM}│${RESET}  ${C}${OS}${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}Kernel     ${RESET}${DIM}│${RESET}  ${C}${KERNEL}${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}CPU        ${RESET}${DIM}│${RESET}  ${C}${CPU_MODEL}${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}Cores      ${RESET}${DIM}│${RESET}  ${C}${CPU_CORES} Cores @ ${CPU_FREQ}${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}Load       ${RESET}${DIM}│${RESET}  ${C}${LOAD_AVG}${RESET}"
echo -e "${BB}║${RESET}  ${P}❯${RESET} ${W}Uptime     ${RESET}${DIM}│${RESET}  ${C}${UPTIME}${RESET}"
echo -e "${BB}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_PERCENT=$(free -m | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}')
RAM_AVAILABLE=$(free -m | awk '/Mem:/ {print $7}')
SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
[ "$SWAP_TOTAL" -gt 0 ] && SWAP_PERCENT=$(free -m | awk '/Swap:/ {printf "%.1f", ($3/$2)*100}') || SWAP_PERCENT="0.0"
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
NET_RX=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null | awk '{printf "%.2f MB", $1/1024/1024}' || echo "0 MB")
NET_TX=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null | awk '{printf "%.2f MB", $1/1024/1024}' || echo "0 MB")

echo -e "${PB}┌──────────────────────────────────────────────────────────────────────┐${RESET}"
echo -e "${PB}│${RESET}  ${W}RAM   ${RESET}${DIM}│${RESET}  ${G}${RAM_USED}MB${RESET} ${DIM}/${RESET} ${C}${RAM_TOTAL}MB${RESET}  ${Y}(${RAM_PERCENT}%)${RESET}  ${DIM}[Free: ${RAM_AVAILABLE}MB]${RESET}"
echo -e "${PB}│${RESET}  ${W}SWAP  ${RESET}${DIM}│${RESET}  ${G}${SWAP_USED}MB${RESET} ${DIM}/${RESET} ${C}${SWAP_TOTAL}MB${RESET}  ${Y}(${SWAP_PERCENT}%)${RESET}"
echo -e "${PB}│${RESET}  ${W}DISK  ${RESET}${DIM}│${RESET}  ${G}${DISK_USED}${RESET} ${DIM}/${RESET} ${C}${DISK_TOTAL}${RESET}  ${Y}${DISK_PERCENT}${RESET}  ${DIM}[Free: ${DISK_AVAILABLE}]${RESET}"
echo -e "${PB}│${RESET}  ${W}NET   ${RESET}${DIM}│${RESET}  ${C}↓ ${NET_RX}${RESET}  ${DIM}│${RESET}  ${G}↑ ${NET_TX}${RESET}"
echo -e "${PB}└──────────────────────────────────────────────────────────────────────┘${RESET}"
echo ""

echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${PB}                    ✦  INSTALLED RUNTIMES  ✦${RESET}"
echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo ""

print_runtime() {
    local name="$1"
    local version_cmd="$2"
    local version=$(eval "$version_cmd" 2>/dev/null)
    local label=$(printf "%-14s" "$name")
    if [ -z "$version" ] || [[ "$version" == *"not found"* ]] || [[ "$version" == *"No such"* ]]; then
        echo -e "  ${P}❯${RESET} ${W}${label}${RESET}  ${DIM}│${RESET}  ${R}✗ Not Installed${RESET}"
    else
        echo -e "  ${P}❯${RESET} ${W}${label}${RESET}  ${DIM}│${RESET}  ${G}✓${RESET} ${C}${version}${RESET}"
    fi
}

ACTIVE_PHP=$(php -v 2>/dev/null | head -n1 | awk '{print $2}')
NODE_VER=$(node -v 2>/dev/null)
BUN_VER=$(bun -v 2>/dev/null | head -n1)
DENO_VER=$(deno --version 2>/dev/null | head -n1 | awk '{print $2}')
PY_VER=$(python3 --version 2>/dev/null | awk '{print $2}')
GO_VER=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
ZIG_VER=$(zig version 2>/dev/null)
RUBY_VER=$(ruby -v 2>/dev/null | awk '{print $2}')
PHP_VER=${ACTIVE_PHP:-"Not Installed"}
JAVA_VER=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}')

print_runtime "Node.js" "echo '$NODE_VER'"
print_runtime "Bun" "echo 'v${BUN_VER}'"
print_runtime "Deno" "echo '$DENO_VER'"
print_runtime "Python" "echo '$PY_VER'"
print_runtime "Go" "echo '$GO_VER'"
print_runtime "Zig" "echo '$ZIG_VER'"
print_runtime "Ruby" "echo '$RUBY_VER'"
print_runtime "PHP" "echo '$PHP_VER'"
print_runtime "Java" "echo '$JAVA_VER'"
print_runtime "Playwright" "playwright --version 2>/dev/null | head -n1"

echo ""

PHP_VERSIONS_INSTALLED=""
for v in 7.4 8.0 8.1 8.2 8.3 8.4; do
    if command -v php${v} &>/dev/null; then
        if [ "$v" == "$(echo $PHP_VER | cut -d. -f1-2)" ]; then
            PHP_VERSIONS_INSTALLED+="${G}[${v}★]${RESET} "
        else
            PHP_VERSIONS_INSTALLED+="${DIM}[${v}]${RESET} "
        fi
    fi
done
echo -e "  ${P}❯${RESET} ${W}PHP Versions  ${RESET}  ${DIM}│${RESET}  ${PHP_VERSIONS_INSTALLED}"
echo ""

echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${PB}                    ✦  INSTALLED TOOLS  ✦${RESET}"
echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo ""

print_runtime "FFmpeg" "ffmpeg -version 2>/dev/null | head -n1 | awk '{print \$3}'"
print_runtime "ImageMagick" "convert -version 2>/dev/null | head -n1 | awk '{print \$3}'"
print_runtime "WebP" "cwebp -version 2>&1 | head -n1"
print_runtime "PM2" "pm2 -v 2>/dev/null"
print_runtime "Nodemon" "nodemon -v 2>/dev/null"
print_runtime "TypeScript" "tsc -v 2>/dev/null"
print_runtime "PNPM" "pnpm -v 2>/dev/null"
print_runtime "Yarn" "yarn -v 2>/dev/null"
print_runtime "Git" "git --version 2>/dev/null | awk '{print \$3}'"
print_runtime "Composer" "composer --version 2>/dev/null | head -n1 | awk '{print \$3}'"
print_runtime "Bundler" "bundler -v 2>/dev/null | awk '{print \$2}'"

echo ""

if pgrep -f cloudflared > /dev/null; then
    echo -e "  ${P}❯${RESET} ${W}CF Tunnel     ${RESET}  ${DIM}│${RESET}  ${G}✓ Active${RESET}"
else
    echo -e "  ${P}❯${RESET} ${W}CF Tunnel     ${RESET}  ${DIM}│${RESET}  ${R}✗ Inactive${RESET}"
fi

echo ""
echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${PB}  ✦ VERLANGID${RESET}  ${DIM}│${RESET}  ${C}t.me/verlangid11${RESET}  ${DIM}│${RESET}  ${C}tiktok.com/@verlangid11${RESET}"
echo -e "${BB}══════════════════════════════════════════════════════════════════════${RESET}"
echo ""

exec /bin/bash
