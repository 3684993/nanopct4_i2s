#!/bin/bash
# 一键初始化 GitHub 仓库，并推送工作流
# 用法: ./action_step_1.sh <github_username> <pat_token> <repo_name>

set -e

if [ $# -ne 3 ]; then
    echo "用法: $0 <github_username> <pat_token> <repo_name>"
    exit 1
fi

USERNAME=$1
TOKEN=$2
REPO_NAME=$3
REPO_URL="https://github.com/$USERNAME/$REPO_NAME.git"
AUTH_URL="https://$USERNAME:$TOKEN@github.com/$USERNAME/$REPO_NAME.git"

echo ">>> 初始化仓库: $REPO_NAME"

# 清理并创建本地目录
rm -rf $REPO_NAME
mkdir -p $REPO_NAME/dts
cd $REPO_NAME
git init -b main

# 创建 README
cat > README.md <<EOF
# $REPO_NAME
自动编译 NanoPC-T4 内核 (启用 I2S1)
EOF

# 创建 workflow
mkdir -p .github/workflows
cat > .github/workflows/build-kernel.yml <<'EOF'
name: Build NanoPC-T4 Kernel (I2S1 Enabled)

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout Repo
        uses: actions/checkout@v4

      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y gcc-aarch64-linux-gnu bc bison flex libssl-dev make git

      - name: Clone Kernel
        run: |
          git clone --depth=1 -b nanopi4-v4.19.y https://github.com/friendlyarm/kernel-rockchip.git

      - name: Replace DTS with custom one
        run: |
          cp dts/rk3399-nanopi4-rev00.dts kernel-rockchip/arch/arm64/boot/dts/rockchip/rk3399-nanopi4-rev00.dts

      - name: Build Kernel
        run: |
          cd kernel-rockchip
          make ARCH=arm64 nanopi4_linux_defconfig CROSS_COMPILE=aarch64-linux-gnu-
          make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-

      - name: Package boot.img
        run: |
          git clone --depth=1 https://github.com/friendlyarm/sd-fuse_rk3399.git
          cd sd-fuse_rk3399
          ./mk-kernel.sh ../kernel-rockchip

      - name: Upload Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: nanopct4-kernel
          path: |
            sd-fuse_rk3399/boot.img
            kernel-rockchip/arch/arm64/boot/Image
            kernel-rockchip/arch/arm64/boot/dts/rockchip/*.dtb
EOF

# Git 提交并推送
git add .
git commit -m "Initial commit with workflow and DTS override"
git remote add origin $AUTH_URL
git push -u origin main --force

echo ">>> 完成。请将你的 DTS 文件放到 dts/ 目录并推送。"

