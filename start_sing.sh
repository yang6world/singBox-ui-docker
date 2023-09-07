#!/bin/bash
imageName="singbox"
#安装功能
function install(){
    read -p "请选择你要安装的设备是有显示器请输入（y/n）：" screen_exist
    if [[ "$screen_exist" =~ ^[Yy]$ ]]; then
        echo "开始安装..."
        echo "清除原有内容"
        docker stop $imageName
        docker rm $imageName
        docker rmi $imageName
        echo "打包镜像"
        docker build -t $imageName .
        if [ $? -ne 0 ]; then
          echo "镜像打包失败，请重试"
          exit 1
        fi
        echo "启动容器"
        docker run -d -it --name=singbox --network=host --privileged=true -u=root -v /root/config/singBox/Dashboard:/singBox/Dashboard -v /root/config/singBox/ProxyProviders:/singBox/ProxyProviders -v /root/config/singBox/RuleProviders:/singBox/RuleProviders -v /root/config/singBox/src:/singBox/src $imageName
        echo "安装完成 请访问WebUi http://localhost:23333"
    else
        echo "开始安装..."
        echo "清除原有内容"
        ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
        docker stop $imageName
        docker rm $imageName
        docker rmi $imageName
        echo "打包镜像"
        docker build -t $imageName .
        if [ $? -ne 0 ]; then
          echo "镜像打包失败，请重试"
          exit 1
        fi
        echo "启动容器"
        docker run -d -it --name=singbox --network=host --privileged=true -u=root -e IP_ADDRESS=$ip -v /root/config/singBox/Dashboard:/singBox/Dashboard -v /root/config/singBox/ProxyProviders:/singBox/ProxyProviders -v /root/config/singBox/RuleProviders:/singBox/RuleProviders -v /root/config/singBox/src:/singBox/src $imageName
        echo "安装完成 请访问WebUi http://$ip:23333"
    fi
    
}




echo "欢迎使用由 Puer 是只喵 喵～ 制作经过修改的Linux神秘模块"
echo "tg地址为 https://t.me/blowh2o/449 "

echo "若你知道你在做什么请输入1"
echo "其他任意键退出"

# 读取用户输入
read choice

# 根据用户输入执行相应操作
case "$choice" in
1)
  echo "您选择了安装功能"
  install
  ;;
*)
  echo "谢谢使用！"
  exit 0
  ;;
esac
