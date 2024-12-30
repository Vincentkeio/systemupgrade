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

# 检查当前系统是否为Debian或Ubuntu
if ! grep -qE 'ubuntu|debian' /etc/os-release; then
  echo "本脚本只支持Debian和Ubuntu系统."
  exit 1
fi

# 提示：提醒用户备份数据
echo "请确保已备份所有重要数据！系统升级可能会导致不稳定，建议备份重要文件。"

# 切换到 root 用户以确保有足够的权限
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 sudo -i 或 su 切换到 root 用户进行操作。"
  exit 1
fi

# 更新当前系统，确保所有软件包都是最新的
echo "正在更新现有的软件包列表..."
apt update && apt upgrade -y && apt dist-upgrade -y

# 清理不需要的包
echo "正在清理不需要的包..."
apt autoremove -y && apt autoclean

# 如果内核有更新，重启系统生效
echo "如果内核更新了，请重新启动计算机以应用最新的内核。"

# 安装系统升级工具
echo "正在安装必要的系统升级工具..."
if grep -q 'ubuntu' /etc/os-release; then
  # 如果是Ubuntu系统，安装 ubuntu-release-upgrader-core
  apt install ubuntu-release-upgrader-core -y
else
  # 如果是Debian系统，安装 update-manager-core
  apt install update-manager-core -y
fi

# 修改 /etc/update-manager/release-upgrades 文件，确保 Prompt 设置为 lts
echo "正在配置升级为 LTS 版本..."
sed -i 's/^Prompt=.*$/Prompt=lts/' /etc/update-manager/release-upgrades

# 方法一：使用 do-release-upgrade 升级
echo "通过 do-release-upgrade 升级系统..."
do-release-upgrade -d

# 如果用户选择跳过 do-release-upgrade 或升级失败，可以选择手动更新 apt 源
echo "如果你希望手动更新 apt 源来升级，请继续执行以下步骤："

# 方法二：手动更新 apt 源文件（如果你希望手动升级）
read -p "是否需要手动更新源文件并继续升级？(y/n): " answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
  echo "正在更新源文件，将旧版本替换为新的版本..."

  # 获取当前系统版本并决定替换为哪个版本
  current_version=$(lsb_release -c | awk '{print $2}')
  new_version=""
  
  if [[ "$current_version" == "jammy" ]]; then
    new_version="noble"
  elif [[ "$current_version" == "bullseye" ]]; then
    new_version="bookworm"
  else
    echo "无法识别当前版本，无法自动替换。"
    exit 1
  fi

  # 替换 apt 源中的旧版本为新版本
  sed -i "s/$current_version/$new_version/g" /etc/apt/sources.list
  sed -i "s/$current_version/$new_version/g" /etc/apt/sources.list.d/*.list

  # 检查是否使用 DEB822 格式（Ubuntu 24.04 及以上）
  if [[ -f /etc/apt/sources.list.d/ubuntu.sources || -f /etc/apt/sources.list.d/debian.sources ]]; then
    echo "检测到 DEB822 格式的源文件，已为新的版本配置更新。"
  else
    echo "使用传统的 One-Line-Style 格式配置源文件。"
  fi

  # 更新系统
  echo "更新软件包列表..."
  apt update && apt upgrade -y && apt dist-upgrade -y

  echo "升级过程中可能会提示一些软件是否需要重启，选择 'Yes' 或按回车即可。"
  echo "在升级过程中，配置文件更新时，请根据需求选择使用新配置文件或保留旧配置文件。"

  # 提示重启
  echo "系统升级完成，请重启计算机。"
fi

# 升级完成后查看当前版本
echo "升级后，查看系统版本..."
lsb_release -a

