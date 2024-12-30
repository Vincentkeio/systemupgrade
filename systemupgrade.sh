#!/bin/bash

# 获取系统详细信息
get_system_info() {
    SYSTEM_NAME=""
    SYSTEM_CODENAME=""
    SYSTEM_VERSION=""
    KERNEL_VERSION=$(uname -r)
    SYSTEM_ARCH=$(uname -m)

    # 1. 尝试通过 /etc/os-release 获取系统信息
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        SYSTEM_NAME=$NAME
        SYSTEM_CODENAME=$VERSION_CODENAME
        SYSTEM_VERSION=$VERSION
    fi

    # 2. 如果 /etc/os-release 没有提供信息，使用 lsb_release 命令
    if [[ -z "$SYSTEM_NAME" ]] && command -v lsb_release &>/dev/null; then
        SYSTEM_NAME=$(lsb_release -i | awk '{print $2}')
        SYSTEM_CODENAME=$(lsb_release -c | awk '{print $2}')
        SYSTEM_VERSION=$(lsb_release -r | awk '{print $2}')
    fi

    # 3. 如果 lsb_release 不可用，读取 /etc/issue 文件
    if [[ -z "$SYSTEM_NAME" ]] && [[ -f /etc/issue ]]; then
        SYSTEM_NAME=$(head -n 1 /etc/issue | awk '{print $1}')
        SYSTEM_CODENAME=$(head -n 1 /etc/issue | awk '{print $2}')
        SYSTEM_VERSION=$(head -n 1 /etc/issue | awk '{print $3}')
    fi

    # 4. 尝试通过 /etc/debian_version 获取 Debian 系统信息
    if [[ -z "$SYSTEM_NAME" ]] && [[ -f /etc/debian_version ]]; then
        SYSTEM_NAME="Debian"
        SYSTEM_CODENAME=$(cat /etc/debian_version)
        SYSTEM_VERSION=$SYSTEM_CODENAME
    fi

    # 5. 尝试使用 dpkg 获取系统信息
    if [[ -z "$SYSTEM_NAME" ]] && command -v dpkg &>/dev/null; then
        SYSTEM_NAME=$(dpkg --status lsb-release | grep "Package" | awk '{print $2}')
        SYSTEM_CODENAME=$(dpkg --status lsb-release | grep "Version" | awk '{print $2}')
        SYSTEM_VERSION=$SYSTEM_CODENAME
    fi

    # 6. 使用 hostnamectl 获取系统信息（适用于 systemd 系统）
    if [[ -z "$SYSTEM_NAME" ]] && command -v hostnamectl &>/dev/null; then
        SYSTEM_NAME=$(hostnamectl | grep "Operating System" | awk -F ' : ' '{print $2}' | awk '{print $1}')
        SYSTEM_CODENAME=$(hostnamectl | grep "Operating System" | awk -F ' : ' '{print $2}' | awk '{print $2}')
        SYSTEM_VERSION=$SYSTEM_CODENAME
    fi

    # 7. 使用 uname 获取内核信息
    if [[ -z "$KERNEL_VERSION" ]]; then
        KERNEL_VERSION=$(uname -r)
    fi

    # 8. 使用 /proc/version 获取内核信息
    if [[ -z "$KERNEL_VERSION" ]] && [[ -f /proc/version ]]; then
        KERNEL_VERSION=$(cat /proc/version | awk '{print $3}')
    fi

    # 9. 如果没有获取到系统信息，退出
    if [[ -z "$SYSTEM_NAME" || -z "$SYSTEM_CODENAME" || -z "$SYSTEM_VERSION" ]]; then
        echo "无法获取系统信息"
        exit 1
    fi
}

# 获取系统信息
get_system_info

# 显示系统详细信息
echo "操作系统: $SYSTEM_NAME"
echo "版本号: $SYSTEM_VERSION"
echo "代号: $SYSTEM_CODENAME"
echo "内核版本: $KERNEL_VERSION"
echo "系统架构: $SYSTEM_ARCH"

#!/bin/bash

# 函数：清理重复的源条目
clean_duplicate_sources() {
    echo "清理重复的源条目..."
    sudo sort /etc/apt/sources.list | uniq | sudo tee /etc/apt/sources.list > /dev/null
    sudo apt update
    echo "重复条目已清理并更新软件包列表。"
}

# 函数：检查当前系统版本
get_current_version() {
    echo "当前系统信息："
    lsb_release -a
    echo "当前内核版本："
    uname -r
}

# 函数：安装升级管理器
install_update_manager() {
    # 安装 update-manager-core 包
    echo "安装 update-manager-core..."
    sudo apt install update-manager-core -y
}

# 函数：升级系统版本
upgrade_system() {
    # 确保系统包是最新的
    echo "更新系统包..."
    sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
    sudo reboot
    
    # 重新获取系统信息
    echo "系统重新启动中..."
    sleep 10
    lsb_release -a
    uname -r

    # 检查是否为LTS版本，若是LTS版本则提示进行升级
    echo "检查是否有新的LTS版本..."
    current_version=$(lsb_release -c | awk '{print $2}')
    echo "当前版本：$current_version"

    # 执行升级
    if [[ "$current_version" == "jammy" ]]; then
        echo "您当前使用的是 Ubuntu 22.04 LTS (Jammy)版本，正在升级到 24.04 LTS..."
        sudo do-release-upgrade -d -y
    elif [[ "$current_version" == "focal" ]]; then
        echo "您当前使用的是 Ubuntu 20.04 LTS (Focal)版本，正在升级到 24.04 LTS..."
        sudo do-release-upgrade -d -y
    else
        echo "当前版本未能检测到更新。"
    fi
}

# 主程序：执行升级步骤
echo "开始升级流程..."

# 1. 清理重复源条目
clean_duplicate_sources

# 2. 获取当前系统信息
get_current_version

# 3. 安装更新管理工具
install_update_manager

# 4. 升级系统
upgrade_system

