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

# Step 1: 备份系统（推荐）
backup_system() {
    echo "建议您在开始之前备份系统。"
    echo "可以使用 Timeshift 工具或其他方式进行备份。"
    echo "建议执行备份后再继续。"
    echo "如果您已经备份，按任意键继续..."
    read -n 1
}

# Step 2: 更新软件包
update_packages() {
    echo "升级当前系统的软件包..."
    sudo apt update
    sudo apt upgrade -y
    sudo reboot
}

# Step 3: 安装 update-manager-core
install_update_manager_core() {
    echo "安装 update-manager-core（如果没有安装的话）..."
    sudo apt install update-manager-core -y
}

# Step 4: 修改 /etc/update-manager/release-upgrades 配置，允许非 LTS 升级
modify_upgrade_config() {
    echo "修改 /etc/update-manager/release-upgrades 配置，允许非 LTS 升级..."
    sudo sed -i 's/Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades
}

# Step 5: 切换到开发版源（确保可以检测到 Ubuntu 24）
switch_to_dev_sources() {
    echo "切换到开发版源以检测 Ubuntu 24..."
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak  # 备份原源配置
    SYSTEM_CODENAME=$(lsb_release -c | awk '{print $2}')

    # 修改源为开发版和提议版源
    sudo sed -i "s/^deb http:\/\/archive.ubuntu.com\/ubuntu/\
deb http:\/\/archive.ubuntu.com\/ubuntu/g" /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu/ $SYSTEM_CODENAME-proposed main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu/ $SYSTEM_CODENAME-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list

    # 更新包列表
    sudo apt update
}

# Step 6: 执行系统升级
perform_upgrade() {
    echo "开始升级到 Ubuntu 24.04 LTS..."
    sudo do-release-upgrade -d
}

# Step 7: 恢复源配置
restore_sources() {
    echo "恢复原来的源配置..."
    sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list
    sudo apt update
}

# 主升级过程
main_upgrade_process() {
    backup_system  # 备份系统
    update_packages  # 更新当前系统包
    install_update_manager_core  # 安装 update-manager-core
    modify_upgrade_config  # 允许非 LTS 升级
    switch_to_dev_sources  # 切换到开发版源以检测更新
    perform_upgrade  # 执行升级
    restore_sources  # 恢复原源配置
    echo "升级完成，请重启计算机以应用更改。"
}

# 执行升级
main_upgrade_process

