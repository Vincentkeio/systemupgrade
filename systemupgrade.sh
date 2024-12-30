#!/bin/bash

# 检查当前系统是否为Debian或Ubuntu
if ! grep -qE 'ubuntu|debian' /etc/os-release; then
  echo "本脚本只支持Debian和Ubuntu系统."
  exit 1
fi

# 更新并升级当前系统
echo "正在更新系统..."
sudo apt update && sudo apt upgrade -y

# 检查是否有新版本
current_release=$(lsb_release -c | awk '{print $2}')
echo "当前系统版本: $current_release"

# 获取可用的新版本
echo "正在检查可用的版本..."
available_versions=$(do-release-upgrade -c | grep -oP 'Candidate version: \K.*')

# 如果没有可用的版本
if [ -z "$available_versions" ]; then
  echo "没有可用的新版本升级."
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
