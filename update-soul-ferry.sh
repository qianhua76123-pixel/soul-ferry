#!/bin/bash
# ================================================================
# 渡魂录 SOUL FERRY - 一键更新脚本
# 用法：把本脚本放到和项目同级目录，然后运行
#   bash update-soul-ferry.sh  /path/to/soul-ferry
# 如不传参数，默认在当前目录找 soul-ferry/
# ================================================================
set -e

REPO_URL="https://github.com/qianhua76123-pixel/soul-ferry.git"
TARGET="${1:-./soul-ferry}"

echo ""
echo "╔═══════════════════════════════════╗"
echo "║  渡魂录 SOUL FERRY  更新工具      ║"
echo "╚═══════════════════════════════════╝"
echo ""

if [ -d "$TARGET/.git" ]; then
    echo "▶ 检测到已有仓库，执行 git pull..."
    cd "$TARGET"
    git pull origin master
    echo "✅ 更新完成"
else
    echo "▶ 未找到仓库，执行 git clone..."
    git clone "$REPO_URL" "$TARGET"
    echo "✅ Clone 完成"
fi

echo ""
echo "项目路径: $(realpath $TARGET)"
echo "现在用 Godot 4 打开 project.godot 即可。"
echo ""
