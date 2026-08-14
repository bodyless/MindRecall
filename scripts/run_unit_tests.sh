#!/usr/bin/env bash
# 跑测 test/ 下全部单元测试（不参与 App 打包）。
# 功能开发或 bug 修复完成后必须执行；失败则非 0 退出，需迭代直至通过。
#
# 用法: ./scripts/run_unit_tests.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="$REPO_ROOT/test"
if [[ ! -d "$TEST_DIR" ]]; then
  echo "测试目录不存在: $TEST_DIR" >&2
  exit 1
fi

echo ""
echo "========================================"
echo " Mind Recall — 单元测试全量跑测"
echo " 目录: test/  (不参与打包)"
echo " 根目录: $REPO_ROOT"
echo "========================================"
echo ""

if ! command -v flutter >/dev/null 2>&1; then
  echo "未找到 flutter 命令，请先安装 Flutter 并加入 PATH。" >&2
  exit 1
fi

set +e
flutter test test/
exit_code=$?
set -e

echo ""
if [[ "$exit_code" -eq 0 ]]; then
  echo "========================================"
  echo " PASSED — 全部单元测试通过"
  echo "========================================"
else
  echo "========================================"
  echo " FAILED — 存在失败用例，请修复后重跑"
  echo " 命令: ./scripts/run_unit_tests.sh"
  echo "========================================"
fi

exit "$exit_code"
