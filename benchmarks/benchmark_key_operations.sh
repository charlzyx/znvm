#!/bin/bash

convert_to_ms() {
    # 将 0m0.003s 格式转换为毫秒
    local time_str="$1"
    local seconds=$(echo "$time_str" | sed 's/0m//' | sed 's/s//')
    local ms=$(echo "$seconds * 1000" | bc | cut -d. -f1)
    echo "${ms}ms"
}

TEST_VERSION="22"

# LIST 命令
echo "Testing LIST command..."
znvm_list=$(convert_to_ms "$({ time znvm list > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")
fnm_list=$(convert_to_ms "$({ time fnm list > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")
nvm_list=$(convert_to_ms "$({ source ~/.nvm/nvm.sh; time nvm list > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")

# USE 命令
echo "Testing USE command..."
znvm_use=$(convert_to_ms "$({ time znvm use $TEST_VERSION > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")
fnm_use=$(convert_to_ms "$({ time fnm use $TEST_VERSION > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")
nvm_use=$(convert_to_ms "$({ source ~/.nvm/nvm.sh; time nvm use $TEST_VERSION > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")

# .nvmrc 测试
echo "Testing .nvmrc parsing..."
TMP_DIR=$(mktemp -d)
echo "22" > "$TMP_DIR/.nvmrc"

znvm_nvmrc=$(convert_to_ms "$({ cd "$TMP_DIR"; time znvm resolve > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")
fnm_nvmrc=$(convert_to_ms "$({ cd "$TMP_DIR"; time fnm env > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")
nvm_nvmrc=$(convert_to_ms "$({ source ~/.nvm/nvm.sh; cd "$TMP_DIR"; time nvm use > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}')")

rm -rf "$TMP_DIR"

# 输出表格
echo ""
echo "Operation | znvm   | fnm   | nvm"
echo "----------|--------|-------|------"
echo "list      | $znvm_list | $fnm_list | $nvm_list"
echo "use       | $znvm_use | $fnm_use | $nvm_use"
echo ".nvmrc    | $znvm_nvmrc | $fnm_nvmrc | $nvm_nvmrc"
echo ""
