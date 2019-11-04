#!/bin/bash

green="\033[32m"
red="\033[31m"
yellow="\033[33m"

font="\033[0m"

install_kernel() {
	echo
	while :; do
    echo -e "${red}内核版本过低，是否进行内核升级:${font} [y/n]"
    read -p "$(echo -e "(默认 y ):")" check_input_one
    [[ -z $check_input_one ]] && check_input_one="y"

		case $check_input_one in
		Y | y)
			echo
			echo -e "${yellow} 开始安装新内核 ${font}"
      rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
      rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
      yum --enablerepo=elrepo-kernel install  kernel-ml-devel kernel-ml -y
      grub2-set-default 0
      seconds_left=10
      echo -e "${seconds_left}秒钟后自动重启，重启后请手动运行 ${red}yum remove kernel ${font}删除旧内核，然后重新运行该脚本完成后续任务"
      while [ $seconds_left -gt 0 ];do
        echo -n $seconds_left
        sleep 1
        seconds_left=$(($seconds_left - 1))
        echo -ne "\r     \r" #清除本行文字
      done
      reboot
			break
			;;
		N | n)
			echo -e "${yellow} 脚本将退出，您可以手动更新内核版本再来运行该脚本。${font}"
			exit 1
			break
			;;
		*)
			error
			;;
		esac
	done
}

# 首先检测内核是否符合要求
kernel_version=`uname -r | awk -F "-" '{print $1}'`
low_version=3.10.1
echo -e "${red}当前内核版本为${font} ${kernel_version}"
# arg1 > arg2为true
function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }

if version_gt $kernel_version $low_version;
then
  echo -e "${green}检测版本号          满足${font}"
else
  install_kernel
fi


# 检测是否为root用户
[[ $(id -u) != 0 ]] && echo -e "\n 请使用 ${red}root ${font}用户运行 ${yellow}~(^_^) ${font}\n" && exit 1

echo -e "${green}检测root用户        满足${font}"

cmd="yum"

sys_bit=$(uname -m)

case $sys_bit in
i[36]86)
        cpu_bit="32"
        cpu_arch="386"
        ;;
x86_64)
        cpu_bit="64"
        cpu_arch="amd64"
        ;;
*armv6*)
        cpu_bit="arm"
        cpu_arch="arm6"
        ;;
*armv7*)
        cpu_bit="arm"
        cpu_arch="arm7"
        ;;
*aarch64* | *armv8*)
        cpu_bit="arm64"
        cpu_arch="arm64"
        ;;
*)
        echo -e "${red}CPU 架构            不满足${font}" && exit 1
        ;;
esac

echo -e "${green}CPU 架构            满足${font}"

# 检测系统是否为RedHat系
if [[ $(command -v yum) ]] && [[ $(command -v systemctl) ]]; then

        if [[ $(command -v yum) ]]; then

                cmd="yum"

        fi
else
    echo -e "${red}此脚本${font} 不支持你的系统。 ${yellow}(-_-) ${font}备注: 仅支持 RedHat系 系统" && exit 1
fi

echo -e "${green}Linux 发行版本      满足${font}"
yum update -y
yum install -y unzip

install_nginx(){
	wget https://test-web-site-resource.s3.ap-east-1.amazonaws.com/oneinstack.zip && unzip oneinstack.zip && ./oneinstack/install.sh --nginx_option 3
	./oneinstack/addons.sh -i --ngx_lua_waf
	rm -f /usr/local/openresty/nginx/conf/nginx.conf
	wget -P /usr/local/openresty/nginx/conf https://test-web-site-resource.s3.ap-east-1.amazonaws.com/nginx.conf
	wget -p /usr/local/openresty/nginx/conf https://test-web-site-resource.s3.ap-east-1.amazonaws.com/vhost.conf
	echo "============================================================================"
	echo -e "${green}环境安装完成，请在启动docker-compose、配置好域名和ssl证书之后手动修改nginx.conf和vhost.conf文件。 ${font}"
	echo -e "${red}注意：1、为了隐藏真实IP，域名不要解析到真实后端服务器，之前有过解析记录指向该服务器IP请更换服务器IP。 ${font}"
	echo -e "${red}     2、nginx.conf只需要删除倒数第二个引入前的注释。 ${font}"
	echo -e "${red}     3、vhost.conf中servername、证书路径、日志路径等请按照实际情况修改。 ${font}"
	echo -e "${red}     4、防火墙相关配置脚本内置有默认规则，如需要定制请联系网管修改。 ${font}"
	echo -e "${red}     5、由于镜像在私有仓库，第一次启动docker-compose前需要执行docker login。 ${font}"
	echo -e "${red}     6、启动docker-compose之前请到/app文件夹内按需修改docker-compose.yml中镜像版本号和需要映射出来的日志等。 ${font}"
	echo "============================================================================"
	exit 1
}

download_yml(){
  wget -P /app https://test-web-site-resource.s3.ap-east-1.amazonaws.com/docker-compose.yml
  echo "${yellow}文件已保存至/app目录下${font}"
	echo -e "${green}Start installing OpenRestry${font}"
	install_nginx
}

install_dockercompose(){
  echo -e "${green}Start installing docker-compose${font}"
  curl -L https://github.com/docker/compose/releases/download/1.24.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  echo -e "${yellow}docker-compose version: $(docker-compose --version)${font}"
  if [[ ! -d /app ]]; then
    #statements
    mkdir /app
    echo "${yellow}app文件夹创建成功${font}"
  fi
  mkdir /app
  echo "${red}是否要下载docker-compose.yml模板文件 y/n :${font}"
  read -p "$(echo -e "(default y ):")" check_input_two
  [[ -z $check_input_two ]] && check_input_two="y"
  if [[ $check_input_two == "y" || $check_input_two == "Y" ]]; then
    #statements
    download_yml
	else
		echo -e "${green}Start installing OpenRestry${font}"
		install_nginx
  fi
}

install_docker(){
  echo -e "${green}下面改成英文提示，提升逼格！${font}"
  echo -e "${green}Start installing docker${font}"
  yum remove -y docker docker-common docker-selinux docker-engine docer-io
  yum install -y yum-utils device-mapper-persistent-data lvm2
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum list docker-ce --showduplicates | sort -r
  echo "${red}Please enter the version you want to install.:${font}"
  read -p "$(echo -e "(default version: ${green}18.06.3.ce ${font}):")" check_input_one
  [[ -z $check_input_one ]] && check_input_one="18.06.3.ce"
  yum install -y docker-ce-$check_input_one
  systemctl start docker
  systemctl enable docker
  echo -e "${green}Docker installed successfully and has started${font}"
  echo -e "docker version: $(docker --version)"
  install_dockercompose
}

install_docker
