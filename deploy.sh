#!/bin/bash
set -e

echo "========================================="
echo "  卓美课表系统 - 一键部署脚本"
echo "========================================="

# 1. 安装 Nginx 和 Git
echo ""
echo "[1/5] 安装 Nginx..."
dnf install -y nginx git > /dev/null 2>&1 || yum install -y nginx git > /dev/null 2>&1
echo "  ✓ Nginx 安装完成"

# 2. 创建网站目录并下载文件
echo ""
echo "[2/5] 下载课表系统..."
mkdir -p /var/www/ketiao
cd /tmp
rm -rf zhuomei-santao-schedule
git clone --depth 1 https://github.com/GaoYliang/zhuomei-santao-schedule.git > /dev/null 2>&1
cp zhuomei-santao-schedule/index.html /var/www/ketiao/
cp zhuomei-santao-schedule/supabase-js.min.js /var/www/ketiao/ 2>/dev/null || true
cp zhuomei-santao-schedule/xlsx.full.min.js /var/www/ketiao/ 2>/dev/null || true
rm -rf zhuomei-santao-schedule
echo "  ✓ 文件下载完成"

# 3. 配置 Nginx
echo ""
echo "[3/5] 配置 Nginx..."
cat > /etc/nginx/conf.d/ketiao.conf << 'NGINX_CONF'
server {
    listen 80;
    server_name _;

    root /var/www/ketiao;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    gzip on;
    gzip_types text/html text/css application/javascript;
    gzip_min_length 1024;

    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_CONF

# 注释掉默认 server 块避免冲突
if [ -f /etc/nginx/nginx.conf ]; then
    sed -i '/^[[:space:]]*server {/,/^[[:space:]]*}/s/^/#/' /etc/nginx/conf.d/default.conf 2>/dev/null || true
fi

echo "  ✓ Nginx 配置完成"

# 4. 配置防火墙
echo ""
echo "[4/5] 配置防火墙..."
firewall-cmd --permanent --add-service=http > /dev/null 2>&1 || true
firewall-cmd --permanent --add-service=https > /dev/null 2>&1 || true
firewall-cmd --reload > /dev/null 2>&1 || true
echo "  ✓ 防火墙配置完成"

# 5. 启动 Nginx
echo ""
echo "[5/5] 启动 Nginx..."
systemctl enable nginx > /dev/null 2>&1
systemctl restart nginx
echo "  ✓ Nginx 已启动"

# 获取服务器 IP
SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 ip.sb 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "========================================="
echo "  部署完成！"
echo "========================================="
echo ""
echo "  访问地址: http://${SERVER_IP}"
echo ""
echo "  网站目录: /var/www/ketiao"
echo "  配置文件: /etc/nginx/conf.d/ketiao.conf"
echo ""
echo "  常用命令:"
echo "    systemctl status nginx    # 查看状态"
echo "    systemctl restart nginx   # 重启"
echo "    systemctl stop nginx      # 停止"
echo "========================================="
