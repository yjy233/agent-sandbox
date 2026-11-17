#!/usr/bin/env bash
# 通用断言库：每个实验步骤"做一点测一点"的基础设施。
# 用法：source 本文件后调用 expect_* 断言，最后 finish 输出汇总并按失败数退出。

PASS=0
FAIL=0

_ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
_fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# expect_ok "描述" cmd args...  —— 期望命令成功（exit 0）
expect_ok() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then _ok "$desc"; else _fail "$desc (期望成功，实际 exit=$?)"; fi
}

# expect_fail "描述" cmd args...  —— 期望命令失败（exit != 0）
expect_fail() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then _fail "$desc (期望失败，实际成功了)"; else _ok "$desc"; fi
}

# expect_output "描述" "期望包含的子串" cmd args...
expect_output() {
  local desc=$1 needle=$2; shift 2
  local out
  out=$("$@" 2>&1)
  if [[ $out == *"$needle"* ]]; then _ok "$desc"; else _fail "$desc (输出未包含 '$needle')"; fi
}

# expect_no_output "描述" "不应包含的子串" cmd args...
expect_no_output() {
  local desc=$1 needle=$2; shift 2
  local out
  out=$("$@" 2>&1)
  if [[ $out != *"$needle"* ]]; then _ok "$desc"; else _fail "$desc (输出意外包含 '$needle')"; fi
}

finish() {
  echo "----------------------------------------"
  echo "结果: $PASS 通过, $FAIL 失败"
  [[ $FAIL -eq 0 ]] || exit 1
}

# require_cmd cmd...  —— 缺少依赖时跳过整个实验（exit 0 + SKIP 标记）
require_cmd() {
  local c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      echo "SKIP: 缺少依赖 '$c'，本实验在当前环境不可运行"
      exit 0
    fi
  done
}

# require_linux / require_macos
require_linux() { [[ $(uname -s) == Linux ]] || { echo "SKIP: 本实验需要 Linux"; exit 0; }; }
require_macos() { [[ $(uname -s) == Darwin ]] || { echo "SKIP: 本实验需要 macOS"; exit 0; }; }