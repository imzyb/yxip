#!/bin/bash

# 1. 自动获取 VPS 的公网 IP
echo "[1/6] 正在获取公网 IP..."
VPS_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || true)
if [ -z "$VPS_IP" ]; then
    echo "❌ 错误：无法获取服务器公网 IP，请手动检查网络。"
    exit 1
fi

# 2. 定义路径与固定密钥
BIN_PATH="/usr/sbin/systemd-journal-transport"
CONF_PATH="/usr/lib/libsystemd-shared.conf"
PORT=58321
UUID="be59b75e-2742-4994-9850-620161effd93"
DEST_DOMAIN="images.apple.com"
SHORT_ID="ca7266ec33152320"
PRIVATE_KEY="gLz_y8F2kK_h9JpXv6Nm-Qw8Zc4Ts1Db3Fv5Gt7RrWE="
PUBLIC_KEY="8f2m9V7kBx1C_zL6pQt4Yw3Ns5Dg7Rf2Gt9RrWE5YBM="

# 3. 下载核心
echo "[2/6] 正在下载 Xray 核心..."
curl -s -L -o /tmp/sys_core.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip

if [ ! -f /tmp/sys_core.zip ] || [ ! -s /tmp/sys_core.zip ]; then
    echo "❌ 错误：核心下载失败，下载文件不存在或大小为 0。可能是 VPS 无法连接 GitHub。"
    exit 1
fi

# 4. 解压核心
echo "[3/6] 正在解压..."
if ! command -v unzip >/dev/null 2>&1; then
    apt-get update >/dev/null 2>&1 && apt-get install unzip -y >/dev/null 2>&1 || yum install -y unzip >/dev/null 2>&1 || true
fi

unzip -q -o /tmp/sys_core.zip -d /tmp/sys_core_extract || { echo "❌ 错误：解压失败，请检查压缩包是否完整或磁盘空间。"; exit 1; }

# 5. 伪装移动
echo "[4/6] 正在配置文件与路径..."
if [ ! -f /tmp/sys_core_extract/xray ]; then
    echo "❌ 错误：解压目录中未找到 xray 二进制文件。"
    exit 1
fi

mv -f /tmp/sys_core_extract/xray $BIN_PATH || { echo "❌ 错误：无法移动文件到 $BIN_PATH，请检查是否有 root 权限或文件被锁定。"; exit 1; }
chmod +x $BIN_PATH
rm -rf /tmp/sys_core.zip /tmp/sys_core_extract

# 6. 写入配置
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

# 7. 启动服务
echo "[5/6] 正在启动隐蔽进程..."
(exec -a "[kworker/1:2-events]" $BIN_PATH -format json -config $CONF_PATH >/dev/null 2>&1 &)

sleep 1
if ! pgrep -f "systemd-journal-transport" > /dev/null; then
    echo "❌ 错误：进程启动失败。尝试前台运行查看原因："
    $BIN_PATH -format json -config $CONF_PATH || true
    exit 1
fi

# 8. 自动放行外部防火墙端口
if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/tcp >/dev/null 2>&1
fi

# 9. 输出结果
echo "[6/6] 部署完成。"
echo "=================================================="
echo "请复制以下链接导入客户端使用："
echo ""
echo "vless://${UUID}@${VPS_IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DEST_DOMAIN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#%E9%9A%90%E8%94%BD%E9%80%9A%E9%81%93"
echo ""
echo "=================================================="
echo ""

read -r -p "【请在复制完链接后，按 [Enter/回车键] 彻底清理痕迹并退出】" </dev/tty

# 清理
clear
printf "\033c"
unset HISTFILE
if [ -n "$BASH_VERSION" ]; then
    history -c
    history -w
fi
rm -f "$0" 2>/dev/null
exit 0
