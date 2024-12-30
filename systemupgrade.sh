#!/bin/bash

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


# 获取当前版本并获取可用版本列表
current_version=$(lsb_release -r | awk '{print $2}')
echo "当前版本: $current_version"

# 获取可用版本列表（通过 Ubuntu 或 Debian 的 release-upgrader 获取）
get_available_versions() {
    local system_type=$1
    local codename=$2
    available_versions=()

    if [[ "$system_type" == "ubuntu" ]]; then
        # 获取 Ubuntu 的所有可用版本
        available_versions=($(apt-cache show ubuntu-release-upgrader-core | grep "Version:" | awk '{print $2}'))
    elif [[ "$system_type" == "debian" ]]; then
        # 获取 Debian 的所有可用版本
        available_versions=($(apt-cache show debian-release-upgrader-core | grep "Version:" | awk '{print $2}'))
    fi

    echo "${available_versions[@]}"
}

# 获取系统的所有可用版本
available_versions=$(get_available_versions "$SYSTEM_TYPE" "$SYSTEM_CODENAME")

# 如果没有可用版本
if [ -z "$available_versions" ]; then
  echo "没有检测到新版本升级。"
  exit 0
fi

# 检测出所有比当前版本更新的版本（包括完全版、实验版、开发版等）
echo "检测到以下可用版本（比当前版本更新）: "
versions=()
for version in $available_versions; do
  if [[ "$version" > "$current_version" ]]; then
    versions+=("$version")
  fi
done

if [ ${#versions[@]} -eq 0 ]; then
  echo "没有检测到比当前版本更新的版本。"
  exit 0
fi

# 列出可用版本并让用户选择
i=1
for version in "${versions[@]}"; do
  echo "$i. $version"
  ((i++))
done

# 用户选择要升级到的版本
read -p "请输入要升级到的版本号 (1-${#versions[@]}): " choice

if [[ "$choice" -lt 1 || "$choice" -gt "${#versions[@]}" ]]; then
  echo "无效的选择，脚本退出."
  exit 1
fi

# 获取选择的版本
selected_version=${versions[$((choice - 1))]}
echo "您选择了升级到: $selected_version"

# 执行升级（Ubuntu 和 Debian 的升级方式不同）
if [[ "$SYSTEM_TYPE" == "ubuntu" ]]; then
    # Ubuntu 使用 do-release-upgrade 进行升级
    echo "正在升级到 $selected_version..."
    sudo do-release-upgrade -d -f DistUpgradeViewNonInteractive
elif [[ "$SYSTEM_TYPE" == "debian" ]]; then
    # Debian 使用修改 /etc/apt/sources.list 来进行升级
    echo "正在升级到 Debian $selected_version..."

    # 更新 sources.list 文件
    sudo sed -i "s/$SYSTEM_CODENAME/$selected_version/g" /etc/apt/sources.list

    # 更新包列表
    sudo apt update

    # 升级系统
    sudo apt full-upgrade -y
fi

# 升级完成后提示
echo "系统升级完成，请重启计算机以应用更改。"
