#!/bin/bash
#
echo -e "\033[32m 是否开启ipv6 \033[0m"
read -p "请输入y/n > " res
sed -i "s/ipv6: false/ipv6: $res/g" /root/config/singBox/config.yaml

echo -e "\033[32m 请选择代理方式 \033[0m"
echo "1. tun模式"
echo "2. Tproxy模式"
read -p "请输入1/2 > " proxy_mode

echo -e "\033[32m 是否启用内置DNS \033[0m"
read -p "请输入y/n > " dns_mode

echo -e "\033[32m  \033[0m"
#将该文件设置的变量存储到config.yaml中
cat <<EOF > $install_dir/config.yaml

install_dir: $install_dir
ipv6: $res
proxy_mode: $proxy_mode
dns_mode: $dns_mode
reread: $reread


EOF