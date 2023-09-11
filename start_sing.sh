#!/bin/bash
imageName="singbox"
install_dir="/root/config"
#检查路径是否正确
function check_dir(){
    if [[ ! "$install_dir" =~ ^[0-9a-zA-Z/_]+$ ]]; then
        echo -e "\033[31m 你的输入不符合规范，请重新输入 \033[0m"
        read -p "安装目录：" install_dir
        install_dir=$(echo "$install_dir" | tr -d '\n')
        echo -e "\033[32m 你的安装目录为 $install_dir \033[0m"
        check_dir
    fi
    if [ ! -d "$install_dir" ]; then
        echo "目录不存在"
        echo "创建目录"
        mkdir -p $install_dir/singBox
        echo "目录创建成功"
    else
        echo "目录存在"
fi
    #检查目录是否有写入权限
    if [ ! -w "$install_dir" ]; then
        echo -e "\033[31m 你的目录没有写入权限，请重新输入 \033[0m"
        read -p "安装目录：" install_dir
        install_dir=$(echo "$install_dir" | tr -d '\n')
        echo -e "\033[32m 你的安装目录为 $install_dir \033[0m"
        check_dir
    fi
    #判断目录是否存在

}

#启动配置流程
function start_config(){
    chmod +x ./scripts/config.sh
    ./scripts/config.sh
}
#安装功能
function install_docker(){
    echo "开始安装docker"
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    #选择是否从源码编译singbox输入y则从源码编译
    read -p "是否从源码编译singbox（y/n）：" build_singbox
    if [[ "$build_singbox" =~ ^[Yy]$ ]]; then
        echo "你选择从源码编译singbox"
        cp ./Docker/Dockerfile.net ./Dockerfile
        elif
        echo "你选择从本地安装singbox"
        cp ./Docker/Dockerfile.local ./Dockerfile
    fi
    read -p "请选择你要安装的设备是有显示器请输入（y/n）：" screen_exist
    if [[ "$screen_exist" =~ ^[Yy]$ ]]; then
        echo "开始安装..."
        echo "清除原有内容"
        docker stop $imageName
        docker rm $imageName
        docker rmi $imageName
        echo "打包镜像"
        docker build --build-arg cpu=$cpu -t $imageName .
        if [ $? -ne 0 ]; then
          echo -e "\033[31m 镜像打包失败，请重试 \033[0m"
          echo "镜像打包失败，请重试"
          exit 1
        fi
        echo "启动容器"
        docker run -d -it --name=singbox --network=host --privileged=true -u=root -v $install_dir/singBox/Dashboard:/singBox/Dashboard -v $install_dir/singBox/ProxyProviders:/singBox/ProxyProviders -v $install_dir/singBox/RuleProviders:/singBox/RuleProviders -v $install_dir/singBox/src:/singBox/src $imageName
        if [ $? -ne 0 ]; then
          echo -e "\033[31m 容器启动失败，请重试 \033[0m"
          exit 1
        fi
        echo "安装完成 请访问WebUi http://localhost:23333"
    else
        echo "开始安装..."
        echo "清除原有内容"
        ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
        docker stop $imageName
        docker rm $imageName
        docker rmi $imageName
        echo "打包镜像"
        #构建镜像传入cpu架构参数cpu
        docker build --build-arg cpu=$cpu -t $imageName .
        if [ $? -ne 0 ]; then
          echo -e "\033[31m 镜像打包失败，请重试 \033[0m"
          exit 1
        fi
        echo "启动容器"
        docker run -d -it --name=singbox --network=host --privileged=true -u=root -e IP_ADDRESS=$ip -v $install_dir/singBox/Dashboard:/singBox/Dashboard -v $install_dir/singBox/ProxyProviders:/singBox/ProxyProviders -v $install_dir/singBox/RuleProviders:/singBox/RuleProviders -v $install_dir/singBox/src:/singBox/src $imageName
        if [ $? -ne 0 ]; then
          echo -e "\033[31m 容器启动失败，请重试 \033[0m"
          exit 1
        fi
        echo "安装完成 请访问WebUi http://$ip:23333"
    fi
    
}

function install_system(){
    echo "安装nodejs-18"
    curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    #判断发行版确定包管理器
    if [ -f /etc/redhat-release ]; then
        echo "你的发行版为CentOS"
        yum install -y nodejs
    elif [ -f /etc/debian_version ]; then
        echo "你的发行版为Debian"
        apt-get install -y nodejs
    elif [ -f /etc/lsb-release ]; then
        echo "你的发行版为Ubuntu"
        apt-get install -y nodejs
    elif [ -f /etc/arch-release ]; then
        echo "你的发行版为Arch"
        pacman -S nodejs
    elif [ -f /etc/SuSE-release ]; then
        echo "你的发行版为SuSE"
        zypper install -y nodejs
    elif [ -f /etc/alpine-release ]; then
        echo "你的发行版为Alpine"
        apk add nodejs
    else
        echo "你的发行版为其他"
        echo "暂不支持你的发行版"
        exit 1
    fi
    #判断系统进程管理器是systemctl还是service还是init
    if [ -f /bin/systemctl ]; then
        echo "你的系统进程管理器为systemctl"
        systemctl start singbox
    elif [ -f /usr/sbin/service ]; then
        echo "你的系统进程管理器为service"
        service singbox start
    elif [ -f /sbin/init ]; then
        echo "你的系统进程管理器为init"
        initctl start singbox
    else
        echo "你的系统进程管理器为其他"
        echo "暂不支持你的系统进程管理器"
        exit 1
    fi
    echo "开始安装..."
    echo "将把singbox安装到系统中"
    echo "安装目录为 /singBox"
    mkdie /singBox
    cp -r ./ /singBox
    wget https://exodusxiaohui.oss-cn-shanghai.aliyuncs.com/singbox/$cpu/singbox -O /singBox/singBox 
    echo "正在添加singbox为开机启动项"
    cp ./scripts/singbox.service /etc/systemd/system/
    systemctl enable singbox
    systemctl start singbox
    echo "安装完成 请访问WebUi http://localhost:23333"
}


#将下列echo输出改为绿色
#优化脚本运行时可以使用退格键删除错误输入

echo -e "\033[32m 欢迎使用由 Puer 是只喵 喵～ 制作,经过yang6world修改的Linux神秘模块 \033[0m"
echo -e "\033[32m tg地址为 https://t.me/blowh2o/449 \033[0m"
echo -e "请输入你的安装目录"
echo -e "例如 /root/config/singBox"
read -p "安装目录：" install_dir
install_dir=$(echo "$install_dir" | tr -d '\n')
echo -e "\033[32m 你的安装目录为 $install_dir \033[0m"
check_dir






echo -e "\033[32m 请选择安装方式 \033[0m"
echo -e "\033[32m 1.使用Docker安装 \033[0m"
echo -e "\033[32m 2.主机安装（可能会遇到未知问题） \033[0m"
echo -e "\033[32m 3.卸载 \033[0m"
echo -e "\033[32m 其他任意键退出 \033[0m"
#检查主机的cpu架构并保存为变量
cpu=$(uname -m)
if [[ "$cpu" =~ ^armv7 ]]; then
    echo "你的设备为armv7架构"
    cpu="armv7"
elif [[ "$cpu" =~ ^armv8 ]]; then
    echo "你的设备为armv8架构"
    cpu="arm64"
elif [[ "$cpu" =~ ^x86_64 ]]; then
    echo "你的设备为x86_64架构"
    cpu="amd64"
elif [[ "$cpu" =~ ^aarch64 ]]; then
    echo "你的设备为aarch64架构"
    cpu="arm64"
elif [[ "$cpu" =~ ^mips ]]; then
    echo "你的设备为mips架构"
    cpu="mips"
else
    echo "你的设备为$cpu 架构"
    echo "暂不支持你的设备"
    exit 1
fi

# 读取用户输入
read choice

# 根据用户输入执行相应操作
case "$choice" in
1)
  echo "您选择了使用Docker安装功能"
  cp -r ./ $install_dir/singBox
  install_docker
  ;;
2)
  echo "您选择了主机安装"
  uninstall
  ;;
3)
  echo "您选择了卸载功能"
  uninstall
  ;;
*)
  echo "谢谢使用！"
  exit 0
  ;;
esac