#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check_cmd() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] ${name}"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] ${name}"
    FAIL=$((FAIL + 1))
  fi
}

echo "== pet-ai 开发环境预检 =="
echo "目录: $(pwd)"
echo "系统: $(sw_vers -productName) $(sw_vers -productVersion)"
echo "架构: $(uname -m)"
echo

check_cmd "Command Line Tools 已安装" xcode-select -p
check_cmd "完整 Xcode 可用（xcodebuild）" xcodebuild -version
check_cmd "Swift 可用" swift --version
check_cmd "Git 可用" git --version
check_cmd "SQLite 可用" sqlite3 --version
check_cmd "xctrace 可用" xctrace version

echo
if [[ -d "/Applications/Xcode.app" ]]; then
  echo "检测到 /Applications/Xcode.app"
else
  echo "未检测到 /Applications/Xcode.app"
fi

echo
echo "== 预检结果 =="
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"

if [[ ${FAIL} -gt 0 ]]; then
  echo "状态: 未通过"
  echo "建议: 安装完整 Xcode 后执行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "状态: 通过"
