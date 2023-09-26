#!/bin/bash
#读取所有配置
install_dir=$(cat /etc/singBox/config.yaml | grep install_dir | awk '{print $2}')
install_ways=$(cat /etc/singBox/config.yaml | grep install_ways | awk '{print $2}')
start=$(cat /etc/singBox/config.yaml | grep start | awk '{print $2}')
ipv6=$(cat /etc/singBox/config.yaml | grep ipv6 | awk '{print $2}')
proxy_mode=$(cat /etc/singBox/config.yaml | grep proxy_mode | awk '{print $2}')
dns_mode=$(cat /etc/singBox/config.yaml | grep dns_mode | awk '{print $2}')

check_status(){
	if [ "$start" = "开启" ]; then
		auto="\033[32m已设置开机启动！\033[0m"
	else
		auto="\033[31m未设置开机启动！\033[0m"
	fi
	#获取运行状态
	#读取singBox.service的运行状态
	status=$(systemctl status singBox | grep active | awk '{print $2}')
	if [ "$status" = "active" ]; then
		magic="已开启"
	else
		magic="未开启"
	fi
	PID=$(pidof singBox | awk '{print $NF}')
	if [ -n "$PID" ];then
		run="\033[32m正在运行（$proxy_mode）\033[0m"
		VmRSS=`cat /proc/$PID/status|grep -w VmRSS|awk '{print $2,$3}'`
		#获取运行时长
		touch /tmp/singBox/singbox_start_time #用于延迟启动的校验
		start_time=$(cat /tmp/singBox/singbox_start_time)
		if [ -n "$start_time" ]; then 
			time=$((`date +%s`-start_time))
			day=$((time/86400))
			[ "$day" = "0" ] && day='' || day="$day天"
			time=`date -u -d @${time} +%H小时%M分%S秒`
		fi
	else
		run="\033[31m没有运行（$proxy_mod）\033[0m"
	fi
    #输出状态
	echo -----------------------------------------------
    echo -e "\033[32m 感谢Shellclash项目为本项目提供的实现方法和灵感\033[0m"
    echo -e "\033[32m 感谢 Puer 是只喵 喵～ 的神秘，为本项目提供的实现方法和灵感\033[0m"
	echo -e "\033[30;46m欢迎使用SingBox！\033[0m"	
    echo -e "安装方式：\033[44m"$install_ways"\033[0m"
	echo -e "神秘面板"$magic"  Singbox服务"$run"，"$auto""
	if [ -n "$PID" ];then
		echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
	fi
	echo -----------------------------------------------
}
singbox_run(){
	#############################
	check_status
	#############################
	echo -e " 1 \033[32m启动/重启\033[0m神秘面板服务"
	echo -e " 2 SingBox\033[33m功能设置(未完成)\033[0m"
	echo -e " 3 \033[31m停止\033[0m神秘面板服务"
	echo -e " 4 \033[36m卸载\033[0m"
	echo -e " 5 \033[36m关闭\033[0m开机启动"
	echo -e " \033[0m任意键退出脚本\033[0m"
	read -p "请输入对应数字 > " num
	if [ "$num" = 1 ]; then
		systemctl restart singBox
		exit;
  
	elif [ "$num" = 2 ]; then
		echo -e "\033[33m该功能尚未完成\033[0m"

	elif [ "$num" = 3 ]; then
		systemctl stop singBox
		echo -----------------------------------------------
		echo -e "\033[31m神秘面板服务已停止！\033[0m"

	elif [ "$num" = 4 ]; then
		source $install_dir/singBox/scripts/uninstall.sh
	elif [ "$num" = 5 ]; then
		systemctl disable singBox
	else
		exit;
	fi

}
singbox_run
