#!/bin/bash
#获取当前脚本目录
cur_dir=$(cd "$(dirname "$0")"; pwd)
fackip="关闭"
quic_rj="关闭"
ipv6_redir="关闭"

echo -e "\033[32m 是否开启开机自启 \033[0m"
read -p "请输入y/n > " reread
if [ "$reread" = "y" ];then
    start="开启"
else
    start="关闭"
fi

echo -e "\033[32m 是否开启ipv6 \033[0m"
read -p "请输入y/n > " res
if [ "$res" = "y" ];then
    ipv6="开启"
else
    ipv6="关闭"
fi


echo -e "\033[32m 请选择代理方式 \033[0m"
echo "1. tun模式"
echo "2. Tproxy模式"
read -p "请输入1/2 > " proxy_mode1
if [ "$proxy_mode1" = "1" ];then
    proxy_mode="tun"
else
    proxy_mode="tproxy"
fi

echo -e "\033[32m 是否启用内置DNS \033[0m"
read -p "请输入y/n > " dns_mode1
if [ "$dns_mode1" = "y" ];then
    dns_mode="开启"
else
    dns_mode="关闭"
fi
echo -e "\033[32m 是否现在重启singbox神秘面板 \033[0m"
read -p "请输入y/n > " singbox1
if [ "$singbox1" = "y" ];then
    systemctl restart singBox
fi

echo -e "\033[32m  \033[0m"
#将该文件设置的变量存储到config.yaml中
cat <<EOF > /etc/singBox/config.yaml
install_ways: $install_ways
start: $start
install_dir: $install_dir
ipv6: $ipv6
proxy_mode: $proxy_mode
dns_mode: $dns_mode
fake_ip: $fake_ip
quic_rj: $quic_rj
ipv6_redir: $ipv6_redir

EOF