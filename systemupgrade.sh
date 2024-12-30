#!/bin/bash

# 获取系统信息，检查是否为 Debian 或 Ubuntu
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
else
    echo "无法识别系统类型。"
    exit 1
fi

# 判断系统是 Debian 还是 Ubuntu
if [[ "$NAME" == "Ubuntu" ]]; then
    SYSTEM_TYPE="ubuntu"
    SYSTEM_CODENAME="$UBUNTU_CODENAME"
elif [[ "$NAME" == "Debian" ]]; then
    SYSTEM_TYPE="debian"
    SYSTEM_CODENAME="$VERSION_CODENAME"
else
    echo "不支持的系统类型: $NAME"
    exit 1
fi

echo "系统类型: $NAME"
echo "版本代号: $SYSTEM_CODENAME"

# 检查并更新系统
echo "正在更新系统..."
sudo apt update && sudo apt upgrade -y

# 确保 do-release-upgrade 工具可用（仅适用于 Ubuntu）
if [[ "$SYSTEM_TYPE" == "ubuntu" && ! $(command -v do-release-upgrade) ]]; then
    echo "未找到 do-release-upgrade 工具，正在安装..."
    sudo apt install -y ubuntu-release-upgrader-core
fi

# 修改 release-upgrades 文件，允许所有版本升级
echo "正在修改系统升级设置，允许所有版本升级..."
sudo sed -i 's/^Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades

# 获取当前版本信息
current_version=$(lsb_release -r | awk '{print $2}')
echo "当前版本: $current_version"

# 定义一个函数来获取并列出所有可用版本
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

# 过滤出比当前版本更新的版本（包括完全版、实验版、开发版等）
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
