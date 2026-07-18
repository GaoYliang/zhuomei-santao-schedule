#!/bin/bash
set -e

echo "========================================="
echo "  卓美课表系统 - 一键部署脚本"
echo "  (Nginx + MySQL + 课表网站)"
echo "========================================="

# 1. 安装基础软件
echo ""
echo "[1/6] 安装 Nginx、Git..."
dnf install -y nginx git > /dev/null 2>&1 || yum install -y nginx git > /dev/null 2>&1
echo "  ✓ Nginx + Git 安装完成"

# 2. 安装 MySQL
echo ""
echo "[2/6] 安装 MySQL..."
# OpenCloudOS 9 / CentOS 9 需要先添加 MySQL 仓库
if ! rpm -q mysql-community-server > /dev/null 2>&1; then
    dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm > /dev/null 2>&1 || true
    dnf module disable -y mysql > /dev/null 2>&1 || true
fi
dnf install -y mysql-community-server mysql-community-client > /dev/null 2>&1 || yum install -y mysql-community-server mysql-community-client > /dev/null 2>&1
systemctl enable mysqld > /dev/null 2>&1
systemctl start mysqld > /dev/null 2>&1

# 获取 MySQL 临时密码
MYSQL_TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log 2>/dev/null | tail -1 | awk '{print $NF}')
echo "  ✓ MySQL 安装完成"
if [ -n "$MYSQL_TEMP_PASS" ]; then
    echo "  ⚠ MySQL 临时密码: $MYSQL_TEMP_PASS"
    echo "  ⚠ 请稍后用以下命令修改密码:"
    echo "    mysql -u root -p'$MYSQL_TEMP_PASS'"
    echo "    ALTER USER 'root'@'localhost' IDENTIFIED BY '你的新密码';"
fi

# 3. 部署课表网站
echo ""
echo "[3/6] 部署课表网站..."
mkdir -p /var/www/ketiao
cp /tmp/zhuomei-santao-schedule/index.html /var/www/ketiao/
cp /tmp/zhuomei-santao-schedule/supabase-js.min.js /var/www/ketiao/ 2>/dev/null || true
cp /tmp/zhuomei-santao-schedule/xlsx.full.min.js /var/www/ketiao/ 2>/dev/null || true
echo "  ✓ 网站文件已部署"

# 4. 配置 Nginx
echo ""
echo "[4/6] 配置 Nginx..."
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
}
NGINX_CONF

# 禁用默认 server 块
if [ -f /etc/nginx/conf.d/default.conf ]; then
    mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true
fi
echo "  ✓ Nginx 配置完成"

# 5. 配置防火墙
echo ""
echo "[5/6] 配置防火墙..."
firewall-cmd --permanent --add-service=http > /dev/null 2>&1 || true
firewall-cmd --permanent --add-service=https > /dev/null 2>&1 || true
firewall-cmd --permanent --add-port=3306/tcp > /dev/null 2>&1 || true
firewall-cmd --reload > /dev/null 2>&1 || true
echo "  ✓ 防火墙已开放 80/443/3306 端口"

# 6. 启动服务
echo ""
echo "[6/6] 启动所有服务..."
systemctl enable nginx > /dev/null 2>&1
systemctl restart nginx
echo "  ✓ Nginx 已启动"

# 获取服务器 IP
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || curl -s --connect-timeout 3 ifconfig.me 2>/dev/null)

echo ""
echo "========================================="
echo "  部署完成！"
echo "========================================="
echo ""
echo "  课表网站: http://${SERVER_IP}"
echo "  网站目录: /var/www/ketiao"
echo ""
echo "  MySQL 状态: $(systemctl is-active mysqld 2>/dev/null || echo '未运行')"
if [ -n "$MYSQL_TEMP_PASS" ]; then
    echo "  MySQL 临时密码: $MYSQL_TEMP_PASS"
    echo "  (请尽快修改密码!)"
fi
echo ""
echo "  常用命令:"
echo "    systemctl status nginx     # Nginx 状态"
echo "    systemctl restart nginx    # 重启 Nginx"
echo "    systemctl status mysqld    # MySQL 状态"
echo "    systemctl restart mysqld   # 重启 MySQL"
echo "========================================="
