#!/bin/bash

# znvm vs fnm vs nvm 性能测试 (2024 重点测试 use 切换)
# 测试项目: ls, use (版本切换) - install 因依赖网速不测试

set -e

ZNVM_ROOT="${HOME}/.znvm"
ITERATIONS=20

# 颜色定义 (为空，禁用颜色)
BLUE=''
GREEN=''
YELLOW=''
RED=''
CYAN=''
NC=''
BOLD=''

# 获取系统信息
get_system_info() {
    echo "$(uname -s) $(uname -m)"
}

# 测量时间 (毫秒)
measure_time() {
    local cmd="$1"
    local start end
    start=$(date +%s%N)
    eval "$cmd" > /dev/null 2>&1 || true
    end=$(date +%s%N)
    echo $(( (end - start) / 1000000 ))
}

# 计算统计数据 (中位数、最小值、最大值、P95)
calc_stats() {
    local arr_name="$1"
    local sorted_str min max median p95
    
    eval "local arr=(\"\${${arr_name}[@]}\")"
    
    sorted_str=$(printf '%s\n' "${arr[@]}" | sort -n)
    local sorted=($(echo "$sorted_str"))
    local len=${#sorted[@]}
    
    [[ $len -eq 0 ]] && echo "0 0 0 0" && return
    
    min=${sorted[0]}
    max=${sorted[$((len-1))]}
    
    if (( len % 2 == 0 )); then
        median=$(( (sorted[$((len/2-1))] + sorted[$((len/2))]) / 2 ))
    else
        median=${sorted[$((len/2))]}
    fi
    
    local p95_idx=$(( len * 95 / 100 ))
    [[ $p95_idx -ge $len ]] && p95_idx=$((len-1))
    p95=${sorted[$p95_idx]}
    
    echo "$min $median $max $p95"
}

# 打印命令测试行
print_cmd_row() {
    printf "  %-12s │ %-14s │ %8s │ %8s │ %8s\n" "$1" "$2" "$3" "$4" "$5"
}

# 检测版本管理器
detect_managers() {
    ZNVM_BIN=""
    if [[ -x "./zig-out/bin/znvm" ]]; then
        ZNVM_BIN="./zig-out/bin/znvm"
    elif command -v znvm &> /dev/null; then
        ZNVM_BIN="$(which znvm)"
    fi
    
    FNM_BIN=""
    if command -v fnm &> /dev/null; then
        FNM_BIN=$(which fnm)
    fi
    
    NVM_DIR="${HOME}/.nvm"
    NVM_AVAILABLE=false
    if [[ -f "$NVM_DIR/nvm.sh" ]]; then
        NVM_AVAILABLE=true
    fi
}

# 获取已安装的版本 (用于测试 use 命令)
get_installed_version() {
    local manager="$1"
    case "$manager" in
        znvm)
            "$ZNVM_BIN" ls 2>/dev/null | grep -E '^\s*v?[0-9]' | head -1 | sed 's/.*v\([0-9.]*\).*/\1/'
            ;;
        fnm)
            fnm list 2>/dev/null | grep -E '^\s*\*?\s*v?[0-9]' | head -1 | sed 's/.*v\([0-9.]*\).*/\1/'
            ;;
        nvm)
            bash -c "source $NVM_DIR/nvm.sh && nvm list 2>/dev/null" | grep -E '^\s*\->?\s*v?[0-9]' | head -1 | sed 's/.*v\([0-9.]*\).*/\1/'
            ;;
    esac
}

# 主程序
clear
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   Node.js 版本管理器性能对比 (重点: use 切换速度)           ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}测试环境:${NC}"
echo "  系统: $(get_system_info)"
echo "  日期: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  迭代次数: ${ITERATIONS}"
echo ""
echo -e "${YELLOW}测试说明:${NC}"
echo "  • ls  - 列出已安装版本"
echo "  • use - 切换到已安装版本 (重点测试)"
echo "  • install 不测试 (依赖网速)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检测版本管理器
detect_managers

echo -e "${BLUE}${BOLD}[检测] 版本管理器状态${NC}"
echo ""
[[ -n "$ZNVM_BIN" ]] && echo -e "  ✓ znvm: ${CYAN}${ZNVM_BIN}${NC}" || echo -e "  ✗ znvm: ${RED}未检测到${NC}"
[[ -n "$FNM_BIN" ]] && echo -e "  ✓ fnm:  ${CYAN}${FNM_BIN}${NC}" || echo -e "  ✗ fnm:  ${RED}未安装${NC}"
[[ "$NVM_AVAILABLE" == true ]] && echo -e "  ✓ nvm:  ${CYAN}${NVM_DIR}/nvm.sh${NC}" || echo -e "  ✗ nvm:  ${RED}未安装${NC}"
echo ""

# 获取已安装版本
echo -e "${BLUE}${BOLD}[检测] 已安装版本${NC}"
echo ""
ZNVM_VERSION=$(get_installed_version "znvm")
FNM_VERSION=$(get_installed_version "fnm")
NVM_VERSION=$(get_installed_version "nvm")

[[ -n "$ZNVM_VERSION" ]] && echo -e "  znvm: ${GREEN}v${ZNVM_VERSION}${NC}" || echo -e "  znvm: ${RED}无已安装版本${NC}"
[[ -n "$FNM_VERSION" ]] && echo -e "  fnm:  ${GREEN}v${FNM_VERSION}${NC}" || echo -e "  fnm:  ${RED}无已安装版本${NC}"
[[ -n "$NVM_VERSION" ]] && echo -e "  nvm:  ${GREEN}v${NVM_VERSION}${NC}" || echo -e "  nvm:  ${RED}无已安装版本${NC}"
echo ""

# ============================================
# 测试 1: 基准 - 纯 Shell 启动
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}${BOLD}[1/3] 基准测试: Shell 启动开销${NC}"
echo ""

baseline_times=()
for i in $(seq 1 $ITERATIONS); do
    t=$(measure_time "bash -c 'echo > /dev/null'")
    baseline_times+=($t)
    [[ $((i % 5)) -eq 0 ]] && echo -n "▸"
done
echo ""

read baseline_min baseline_med baseline_max baseline_p95 <<< "$(calc_stats baseline_times)"
echo -e "  Shell 启动: ${GREEN}min=${baseline_min}ms, med=${baseline_med}ms, max=${baseline_max}ms${NC}"
echo ""

# ============================================
# 测试 2: ls 命令
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}${BOLD}[2/3] 测试: ls (list) 命令${NC}"
echo ""

# znvm ls
if [[ -n "$ZNVM_BIN" ]]; then
    echo -e "  测试 ${CYAN}znvm ls${NC}..."
    znvm_ls_times=()
    for i in $(seq 1 $ITERATIONS); do
        t=$(measure_time "${ZNVM_BIN} ls")
        znvm_ls_times+=($t)
        [[ $((i % 5)) -eq 0 ]] && echo -n "▸"
    done
    echo ""
    read znvm_ls_min znvm_ls_med znvm_ls_max znvm_ls_p95 <<< "$(calc_stats znvm_ls_times)"
    znvm_ls_net=$((znvm_ls_med - baseline_med))
    [[ $znvm_ls_net -lt 0 ]] && znvm_ls_net=0
    echo -e "    结果: ${GREEN}${znvm_ls_med}ms${NC} (净: ${YELLOW}${znvm_ls_net}ms${NC})"
else
    znvm_ls_med="N/A"; znvm_ls_net="N/A"
    znvm_ls_min="N/A"; znvm_ls_p95="N/A"
fi
echo ""

# fnm list
if [[ -n "$FNM_BIN" ]]; then
    echo -e "  测试 ${CYAN}fnm list${NC}..."
    fnm_ls_times=()
    for i in $(seq 1 $ITERATIONS); do
        t=$(measure_time "fnm list")
        fnm_ls_times+=($t)
        [[ $((i % 5)) -eq 0 ]] && echo -n "▸"
    done
    echo ""
    read fnm_ls_min fnm_ls_med fnm_ls_max fnm_ls_p95 <<< "$(calc_stats fnm_ls_times)"
    fnm_ls_net=$((fnm_ls_med - baseline_med))
    [[ $fnm_ls_net -lt 0 ]] && fnm_ls_net=0
    echo -e "    结果: ${GREEN}${fnm_ls_med}ms${NC} (净: ${YELLOW}${fnm_ls_net}ms${NC})"
else
    fnm_ls_med="N/A"; fnm_ls_net="N/A"
    fnm_ls_min="N/A"; fnm_ls_p95="N/A"
fi
echo ""

# nvm list
if [[ "$NVM_AVAILABLE" == true ]]; then
    echo -e "  测试 ${CYAN}nvm list${NC}..."
    nvm_ls_times=()
    for i in $(seq 1 $ITERATIONS); do
        t=$(measure_time "bash -c 'source ${NVM_DIR}/nvm.sh && nvm list'")
        nvm_ls_times+=($t)
        [[ $((i % 5)) -eq 0 ]] && echo -n "▸"
    done
    echo ""
    read nvm_ls_min nvm_ls_med nvm_ls_max nvm_ls_p95 <<< "$(calc_stats nvm_ls_times)"
    nvm_ls_net=$((nvm_ls_med - baseline_med))
    [[ $nvm_ls_net -lt 0 ]] && nvm_ls_net=0
    echo -e "    结果: ${GREEN}${nvm_ls_med}ms${NC} (净: ${YELLOW}${nvm_ls_net}ms${NC})"
else
    nvm_ls_med="N/A"; nvm_ls_net="N/A"
    nvm_ls_min="N/A"; nvm_ls_p95="N/A"
fi
echo ""

# ============================================
# 测试 3: use 命令 (重点 - 版本切换)
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}${BOLD}[3/3] 测试: use 命令 (版本切换) ⭐ 重点${NC}"
echo ""

# znvm use
if [[ -n "$ZNVM_BIN" && -n "$ZNVM_VERSION" ]]; then
    echo -e "  测试 ${CYAN}znvm use ${ZNVM_VERSION}${NC}..."
    znvm_use_times=()
    for i in $(seq 1 $ITERATIONS); do
        t=$(measure_time "${ZNVM_BIN} use ${ZNVM_VERSION}")
        znvm_use_times+=($t)
        [[ $((i % 5)) -eq 0 ]] && echo -n "▸"
    done
    echo ""
    read znvm_use_min znvm_use_med znvm_use_max znvm_use_p95 <<< "$(calc_stats znvm_use_times)"
    znvm_use_net=$((znvm_use_med - baseline_med))
    [[ $znvm_use_net -lt 0 ]] && znvm_use_net=0
    echo -e "    结果: ${GREEN}${znvm_use_med}ms${NC} (净: ${YELLOW}${znvm_use_net}ms${NC})"
else
    [[ -n "$ZNVM_BIN" ]] && echo -e "  ${YELLOW}znvm: 无已安装版本，跳过 use 测试${NC}"
    znvm_use_med="N/A"; znvm_use_net="N/A"
    znvm_use_min="N/A"; znvm_use_p95="N/A"
fi
echo ""

# fnm use
if [[ -n "$FNM_BIN" && -n "$FNM_VERSION" ]]; then
    echo -e "  测试 ${CYAN}fnm use ${FNM_VERSION}${NC}..."
    fnm_use_times=()
    for i in $(seq 1 $ITERATIONS); do
        t=$(measure_time "fnm use ${FNM_VERSION}")
        fnm_use_times+=($t)
        [[ $((i % 5)) -eq 0 ]] && echo -n "▸"
    done
    echo ""
    read fnm_use_min fnm_use_med fnm_use_max fnm_use_p95 <<< "$(calc_stats fnm_use_times)"
    fnm_use_net=$((fnm_use_med - baseline_med))
    [[ $fnm_use_net -lt 0 ]] && fnm_use_net=0
    echo -e "    结果: ${GREEN}${fnm_use_med}ms${NC} (净: ${YELLOW}${fnm_use_net}ms${NC})"
else
    [[ -n "$FNM_BIN" ]] && echo -e "  ${YELLOW}fnm: 无已安装版本，跳过 use 测试${NC}"
    fnm_use_med="N/A"; fnm_use_net="N/A"
    fnm_use_min="N/A"; fnm_use_p95="N/A"
fi
echo ""

# nvm use
if [[ "$NVM_AVAILABLE" == true && -n "$NVM_VERSION" ]]; then
    echo -e "  测试 ${CYAN}nvm use ${NVM_VERSION}${NC}..."
    nvm_use_times=()
    for i in $(seq 1 $ITERATIONS); do
        t=$(measure_time "bash -c 'source ${NVM_DIR}/nvm.sh && nvm use ${NVM_VERSION}'")
        nvm_use_times+=($t)
        [[ $((i % 5)) -eq 0 ]] && echo -n "▸"
    done
    echo ""
    read nvm_use_min nvm_use_med nvm_use_max nvm_use_p95 <<< "$(calc_stats nvm_use_times)"
    nvm_use_net=$((nvm_use_med - baseline_med))
    [[ $nvm_use_net -lt 0 ]] && nvm_use_net=0
    echo -e "    结果: ${GREEN}${nvm_use_med}ms${NC} (净: ${YELLOW}${nvm_use_net}ms${NC})"
else
    [[ "$NVM_AVAILABLE" == true ]] && echo -e "  ${YELLOW}nvm: 无已安装版本，跳过 use 测试${NC}"
    nvm_use_med="N/A"; nvm_use_net="N/A"
    nvm_use_min="N/A"; nvm_use_p95="N/A"
fi
echo ""

# ============================================
# 汇总表格
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BOLD}${CYAN}📊 性能对比汇总 (中位数, 单位: ms)${NC}"
echo ""

# ls 命令汇总
echo -e "${BOLD}【ls / list 命令】${NC}"
echo -e "${BOLD}  管理器       │   总时间   │  净执行*  │  最小值  │  P95   ${NC}"
echo "  ─────────────┼───────────┼──────────┼─────────┼────────"
[[ "$znvm_ls_med" != "N/A" ]] && print_cmd_row "znvm" "ls" "${znvm_ls_med}ms" "${znvm_ls_net}ms" "${znvm_ls_p95}ms"
[[ "$fnm_ls_med" != "N/A" ]] && print_cmd_row "fnm" "list" "${fnm_ls_med}ms" "${fnm_ls_net}ms" "${fnm_ls_p95}ms"
[[ "$nvm_ls_med" != "N/A" ]] && print_cmd_row "nvm" "list" "${nvm_ls_med}ms" "${nvm_ls_net}ms" "${nvm_ls_p95}ms"
echo ""

# use 命令汇总 (重点)
echo -e "${BOLD}${CYAN}【use 命令 ⭐ 重点】${NC}"
echo -e "${BOLD}  管理器       │   总时间   │  净执行*  │  最小值  │  P95   ${NC}"
echo "  ─────────────┼───────────┼──────────┼─────────┼────────"
[[ "$znvm_use_med" != "N/A" ]] && print_cmd_row "znvm" "use v${ZNVM_VERSION}" "${znvm_use_med}ms" "${znvm_use_net}ms" "${znvm_use_p95}ms"
[[ "$fnm_use_med" != "N/A" ]] && print_cmd_row "fnm" "use v${FNM_VERSION}" "${fnm_use_med}ms" "${fnm_use_net}ms" "${fnm_use_p95}ms"
[[ "$nvm_use_med" != "N/A" ]] && print_cmd_row "nvm" "use v${NVM_VERSION}" "${nvm_use_med}ms" "${nvm_use_net}ms" "${nvm_use_p95}ms"
echo ""
echo "  *净执行 = 总时间 - Shell启动基准(${baseline_med}ms)"
echo ""

# ============================================
# 性能排名
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BOLD}${CYAN}🏆 性能排名 (净执行时间)${NC}"
echo ""

echo -e "${BOLD}【ls 命令】${NC}"
[[ "$znvm_ls_net" =~ ^[0-9]+$ ]] && echo "  znvm: ${znvm_ls_net}ms"
[[ "$fnm_ls_net" =~ ^[0-9]+$ ]] && echo "  fnm:  ${fnm_ls_net}ms"
[[ "$nvm_ls_net" =~ ^[0-9]+$ ]] && echo "  nvm:  ${nvm_ls_net}ms"
echo ""

echo -e "${BOLD}${CYAN}【use 命令 ⭐】${NC}"
[[ "$znvm_use_net" =~ ^[0-9]+$ ]] && echo "  znvm: ${znvm_use_net}ms"
[[ "$fnm_use_net" =~ ^[0-9]+$ ]] && echo "  fnm:  ${fnm_use_net}ms"
[[ "$nvm_use_net" =~ ^[0-9]+$ ]] && echo "  nvm:  ${nvm_use_net}ms"
echo ""

# ============================================
# 综合结论
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BOLD}${CYAN}📈 综合性能数据${NC}"
echo ""
printf "  %-8s │ %10s │ %10s │ %s\n" "管理器" "ls" "use ⭐" "结论"
echo "  ─────────┼───────────┼───────────┼──────────────────────────────"
printf "  %-8s │ %10s │ %10s │ %s\n" "znvm" "${znvm_ls_net:-N/A}ms" "${znvm_use_net:-N/A}ms" ""
printf "  %-8s │ %10s │ %10s │ %s\n" "fnm" "${fnm_ls_net:-N/A}ms" "${fnm_use_net:-N/A}ms" ""
printf "  %-8s │ %10s │ %10s │ %s\n" "nvm" "${nvm_ls_net:-N/A}ms" "${nvm_use_net:-N/A}ms" ""
echo ""

# 计算 winner
fastest_ls=""
fastest_use=""
ls_min=999999
use_min=999999

[[ "$znvm_ls_net" =~ ^[0-9]+$ ]] && [[ $znvm_ls_net -lt $ls_min ]] && ls_min=$znvm_ls_net && fastest_ls="znvm"
[[ "$fnm_ls_net" =~ ^[0-9]+$ ]] && [[ $fnm_ls_net -lt $ls_min ]] && ls_min=$fnm_ls_net && fastest_ls="fnm"
[[ "$nvm_ls_net" =~ ^[0-9]+$ ]] && [[ $nvm_ls_net -lt $ls_min ]] && ls_min=$nvm_ls_net && fastest_ls="nvm"

[[ "$znvm_use_net" =~ ^[0-9]+$ ]] && [[ $znvm_use_net -lt $use_min ]] && use_min=$znvm_use_net && fastest_use="znvm"
[[ "$fnm_use_net" =~ ^[0-9]+$ ]] && [[ $fnm_use_net -lt $use_min ]] && use_min=$fnm_use_net && fastest_use="fnm"
[[ "$nvm_use_net" =~ ^[0-9]+$ ]] && [[ $nvm_use_net -lt $use_min ]] && use_min=$nvm_use_net && fastest_use="nvm"

echo -e "${GREEN}ls 命令最快: ${fastest_ls:-N/A} (${ls_min}ms)${NC}"
echo -e "${GREEN}use 命令最快: ${fastest_use:-N/A} (${use_min}ms)${NC}"
echo ""

# 计算倍数
if [[ -n "$fastest_use" && "$fastest_use" != "nvm" && "$nvm_use_net" =~ ^[0-9]+$ ]]; then
    ratio=$(echo "scale=1; $nvm_use_net / $use_min" | bc 2>/dev/null || echo "N/A")
    [[ "$ratio" != "N/A" ]] && echo -e "${YELLOW}nvm use 比 ${fastest_use} use 慢 ${ratio}x${NC}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BOLD}测试完成!${NC}"
echo ""
