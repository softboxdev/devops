#!/bin/bash

echo "=== Начинаем удаление NGINX ==="

# Останавливаем NGINX
echo "1. Останавливаем NGINX..."
sudo systemctl stop nginx
sudo systemctl disable nginx

# Удаляем пакеты
echo "2. Удаляем пакеты NGINX..."
sudo apt purge nginx nginx-common nginx-core nginx-full nginx-extras -y

# Очищаем зависимости
echo "3. Очищаем зависимости..."
sudo apt autoremove -y
sudo apt autoclean

# Удаляем файлы
echo "4. Удаляем оставшиеся файлы..."
sudo rm -rf /etc/nginx/
sudo rm -rf /var/log/nginx/
sudo rm -rf /var/cache/nginx/
sudo rm -f /etc/systemd/system/nginx.service
sudo rm -f /lib/systemd/system/nginx.service

# Обновляем systemd
echo "5. Обновляем systemd..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "=== Удаление NGINX завершено ==="

# Проверка
echo "Проверка удаления:"
dpkg -l | grep nginx
ps aux | grep nginx
EOF
