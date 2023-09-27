#!/bin/bash
#读取所有配置
install_dir=$(cat /etc/singBox/config.yaml | grep install_dir | awk '{print $2}')
install_ways=$(cat /etc/singBox/config.yaml | grep install_ways | awk '{print $2}')
start=$(cat /etc/singBox/config.yaml | grep start | awk '{print $2}')
ipv6=$(cat /etc/singBox/config.yaml | grep ipv6 | awk '{print $2}')
proxy_mode=$(cat /etc/singBox/config.yaml | grep proxy_mode | awk '{print $2}')
dns_mode=$(cat /etc/singBox/config.yaml | grep dns_mode | awk '{print $2}')

modify_yaml_key() {
  local yaml_file="$1"
  local key_to_modify="$2"
  local new_value="$3"

  # 检查是否存在要修改的键
  if [[ -f "$yaml_file" ]]; then
    yaml_content=$(<"$yaml_file")

    if [[ $yaml_content == *"$key_to_modify:"* ]]; then
      # 使用正则表达式来查找要修改的键的行
      key_line=$(echo "$yaml_content" | grep -n "$key_to_modify:" | cut -d: -f1)
      # 计算缩进级别
      indent=$(echo "${yaml_content}" | sed -n "${key_line}p" | awk -F"$key_to_modify:" '{print $1}')
      # 替换键对应的值
      new_line="${indent}${key_to_modify}: $new_value"
      updated_yaml_content=$(echo "$yaml_content" | sed "${key_line}s/.*/$new_line/")
      # 保存更新后的内容回文件
      echo "$updated_yaml_content" > "$yaml_file"

      echo "配置已更新"
    else
      echo "未找到要修改的键: $key_to_modify"
    fi
  else
    echo "YAML 文件不存在: $yaml_file"
  fi
}

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
proxy_config(){
	echo -----------------------------------------------
	echo "设置代理方式"
	echo -----------------------------------------------
	echo -e " 1 \033[32m代理模式：$proxy_mode模式\033[0m"
	echo -e " 2 \033[32mFakeIP开关：$fackip\033[0m"
	echo -e " 3 \033[32m\033[0m"
	read num1
	

}
singbox_run
