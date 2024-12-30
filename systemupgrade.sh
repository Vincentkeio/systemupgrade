#!/bin/bash

# 检查当前系统是否为Debian或Ubuntu
if ! grep -qE 'ubuntu|debian' /etc/os-release; then
  echo "本脚本只支持Debian和Ubuntu系统."
  exit 1
fi

# 获取当前系统版本信息
current_release=$(lsb_release -c | awk '{print $2}')
echo "当前系统版本: $current_release"

# 更新并升级当前系统
echo "正在更新系统..."
sudo apt update && sudo apt upgrade -y

# 确保 do-release-upgrade 可用
if ! command -v do-release-upgrade &> /dev/null; then
  echo "未找到 do-release-upgrade 工具，正在安装..."
  sudo apt install -y ubuntu-release-upgrader-core
fi

# 修改 release-upgrades 文件，强制升级到开发版
sudo sed -i 's/^Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades

# 使用 apt-cache 获取当前发行版的可用版本
echo "正在检查可用版本..."
if [[ $(lsb_release -i | awk '{print $2}') == "Ubuntu" ]]; then
  # Ubuntu 系统
  available_versions=$(apt-cache showpkg ubuntu-release-upgrader-core | grep "Version:" | awk '{print $2}')
elif [[ $(lsb_release -i | awk '{print $2}') == "Debian" ]]; then
  # Debian 系统
  available_versions=$(apt-cache showpkg debian-release-upgrader-core | grep "Version:" | awk '{print $2}')
else
  echo "无法识别系统版本."
  exit 1
fi

# 如果没有可用的版本
if [ -z "$available_versions" ]; then
  echo "没有检测到新版本升级。"
  exit 0
fi

# 列出可用版本并让用户选择
echo "检测到以下可用版本: "
versions=($available_versions)
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

# 升级到选定的版本
echo "正在升级到 $selected_version..."
sudo do-release-upgrade -d -f DistUpgradeViewNonInteractive

# 升级完成后提示
echo "系统升级完成，请重启计算机以应用更改。"
