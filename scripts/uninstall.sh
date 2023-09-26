#!/bin/bash
#读取配置文件
install_dir=$(cat /etc/singBox/config.yaml | grep install_dir | awk '{print $2}')
install_ways=$(cat /etc/singBox/config.yaml | grep install_ways | awk '{print $2}')
read -p "是否确认卸载（y/n）：" uninstall_confirm
if [[ ! "$uninstall_confirm" =~ ^[Yy]$ ]]; then
    echo "取消卸载"
    exit 0
fi
echo "开始卸载..."
if [ "$install_ways" = "system" ]; then
    #检查/etc/systemd/system/下是否有singBox.service
    if [ ! -f /etc/systemd/system/singBox.service ]; then
        echo -e "\033[32m 未检测到singBox.service \033[0m"
        echo -e "\033[32m 卸载完成 \033[0m"
        exit 0
    else
        echo -e "\033[32m 检测到singBox.service \033[0m"
        echo -e "\033[32m 正在停止singBox.service \033[0m"
        systemctl stop singBox
        echo -e "\033[32m 正在删除singBox.service \033[0m"
        rm /etc/systemd/system/singBox.service
        echo -e "\033[32m 正在重载systemctl \033[0m"
        systemctl daemon-reload
        echo -e "\033[32m 正在重启systemctl \033[0m"
        systemctl reset-failed
        echo -e "\033[32m 卸载完成 \033[0m"
    fi
else
    echo -e "\033[32m 检测到singbox容器 \033[0m"
    echo -e "\033[32m 正在停止singbox容器 \033[0m"
    docker stop singbox
    echo -e "\033[32m 正在删除singbox容器 \033[0m"
    docker rm singbox
    echo -e "\033[32m 卸载完成 \033[0m"
fi
rm /usr/local/bin/singbox
rm -rf /etc/singBox
rm -rf $install_dir