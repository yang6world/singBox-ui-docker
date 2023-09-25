#!/bin/bash
#读取所有配置
install_dir=$(cat ./config.yaml | grep install_dir | awk '{print $2}')
install_ways=$(cat ./config.yaml | grep install_ways | awk '{print $2}')
start=$(cat ./config.yaml | grep start | awk '{print $2}')
ipv6=$(cat ./config.yaml | grep ipv6 | awk '{print $2}')
proxy_mode=$(cat ./config.yaml | grep proxy_mode | awk '{print $2}')
dns_mode=$(cat ./config.yaml | grep dns_mode | awk '{print $2}')

check_status(){
	if [ "$start" = "开启" ]; then
		auto="\033[32m已设置开机启动！\033[0m"
		auto1="\033[36m禁用\033[0msingBox开机启动"
	else
		auto="\033[31m未设置开机启动！\033[0m"
		auto1="\033[36m允许\033[0msingBox开机启动"
	fi
	#获取运行状态
	PID=$(pidof singbox | awk '{print $NF}')
	if [ -n "$PID" ];then
		run="\033[32m正在运行（$redir_mod）\033[0m"
		VmRSS=`cat /proc/$PID/status|grep -w VmRSS|awk '{print $2,$3}'`
		#获取运行时长
		touch $TMPDIR/singbox_start_time #用于延迟启动的校验
		start_time=$(cat $TMPDIR/clash_start_time)
		if [ -n "$start_time" ]; then 
			time=$((`date +%s`-start_time))
			day=$((time/86400))
			[ "$day" = "0" ] && day='' || day="$day天"
			time=`date -u -d @${time} +%H小时%M分%S秒`
		fi
	else
		run="\033[31m没有运行（$redir_mod）\033[0m"
		#检测系统端口占用
		checkport
	fi
    #输出状态
	echo -----------------------------------------------
    echo -e "\033[30;46m 感谢Shellclash项目为本项目提供的实现方法和灵感\033[0m"
    echo -e "\033[30;46m 感谢 Puer 是只喵 喵～ 的神秘，为本项目提供的实现方法和灵感\033[0m"
	echo -e "\033[30;46m欢迎使用SingBox！\033[0m	
    echo -e "安装方式：\033[44m"$install_ways"\033[0m"
	echo -e "SingBox服务"$run"，"$auto""
	if [ -n "$PID" ];then
		echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
	fi
	echo -----------------------------------------------
}