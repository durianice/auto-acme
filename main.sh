#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "请切换至ROOT用户" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i"
    if [[ -n $SYS ]]; then
        break
    fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        if [[ -n $SYSTEM ]]; then
            break
        fi
    fi
done

[[ -z $SYSTEM ]] && red "你所在的操作系统不支持该脚本" && exit 1

back2menu() {
    echo ""
    green "所选命令操作执行完成"
    read -rp "请输入“y”退出, 或按任意键回到主菜单：" back2menuInput
    case "$back2menuInput" in
        y) exit 1 ;;
        *) menu ;;
    esac
}

brefore_install(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo socat openssl
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} cronie
        systemctl start crond
        systemctl enable crond
    else
        ${PACKAGE_INSTALL[int]} cron
        systemctl start cron
        systemctl enable cron
    fi
}

install(){
    brefore_install
    cd ~
    PLAIN "下载Acme.sh"
    curl https://get.acme.sh | sh
    alias acme.sh=~/.acme.sh/acme.sh
     if [[ -n $(acme.sh -v 2>/dev/null) ]]; then
        green "Acme脚本安装成功"
    else
        red "Acme脚本安装失败" && exit 1
    fi
    source ~/.bashrc
    acme.sh --upgrade --auto-upgrade
  
    yellow "默认服务商为letsencrypt"
    acme.sh --set-default-ca --server letsencrypt
    
    read -rp "请输入域名: (example.com)" domain
    if [[ $(echo ${domain:0-2}) =~ cf|ga|gq|ml|tk ]]; then
        red "Freenom域名请使用其他模式"
        back2menu
    fi
    
    read -rp "请输入CloudFlare Global API Key: " GAK
    [[ -z $GAK ]] && red "未输入CloudFlare Global API Key, 无法执行操作!" && exit 1
    export CF_Key="$GAK"
    
    read -rp "请输入CloudFlare的登录邮箱: " CFemail
    [[ -z $domain ]] && red "未输入CloudFlare的登录邮箱, 无法执行操作!" && exit 1
    export CF_Email="$CFemail"
    
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
    
    if [[ -z $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d "*.${domain}" -d "${domain}" -k ec-256 --listen-v6 --insecure
    else
        bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d "*.${domain}" -d "${domain}" -k ec-256 --insecure
    fi
    {
        bash ~/.acme.sh/acme.sh --install-cert -d "*.${domain}" --key-file /root/cert/private.key --fullchain-file /root/cert/cert.crt --ecc
        chmod -R 755 /root/cert
        green "证书申请成功，保存路径：/root/cert/"
    } || {
        red "证书生成失败"
    }
    back2menu
}

uninstall() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装Acme.sh, 卸载程序无法执行!" && exit 1
    ~/.acme.sh/acme.sh --uninstall
    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
    rm -rf ~/.acme.sh
    green "已卸载Acme.sh"
}

menu() {
    clear
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装Acme并申请证书"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载本脚本${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项执行: " NumberInput
    case "$NumberInput" in
        1) install ;;
        2) uninstall ;;
        *) exit 1 ;;
    esac
}

menu
