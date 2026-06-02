#!/usr/bin/env bash
# ============================================================================
# check_facade_exports.sh — Facade 导出完整性审计
#
# 功能：检测外部代码调用了 Facade 模块的方法，但 Facade 文件中未导出的情况
# 用途：防止文件拆分后 facade 漏导出方法（历史事故：IsCompleted、IsUnlocked、CheckSaveExists）
#
# 用法：bash scripts/tests/check_facade_exports.sh
# 返回：0 = 全部通过；1 = 存在缺失导出
# ============================================================================

set -euo pipefail

SCRIPTS_DIR="/workspace/scripts"
ERRORS=0

# ─────────────────────────────────────────────────────────────────────────────
# Facade 注册表：facade文件 → 模块名
# 添加新 facade 时在此注册
# ─────────────────────────────────────────────────────────────────────────────
declare -A FACADES=(
    ["systems/ChallengeSystem.lua"]="ChallengeSystem"
    ["systems/InventorySystem.lua"]="InventorySystem"
    ["systems/LootSystem.lua"]="LootSystem"
    ["systems/SkillSystem.lua"]="SkillSystem"
    ["rendering/EffectRenderer.lua"]="EffectRenderer"
    ["rendering/EntityRenderer.lua"]="EntityRenderer"
    ["config/EquipmentData_Collection.lua"]="EquipmentData_Collection"
    ["config/EquipmentData_Forge.lua"]="EquipmentData_Forge"
    ["config/EquipmentData_Special.lua"]="EquipmentData_Special"
)

# 动态 re-export facade（无法静态审计，跳过）
declare -A DYNAMIC_FACADES=(
    ["rendering/EntityRenderer.lua"]=1
)

# ─────────────────────────────────────────────────────────────────────────────
# 对每个 facade 执行审计
# ─────────────────────────────────────────────────────────────────────────────

for facade_rel in "${!FACADES[@]}"; do
    MODULE_NAME="${FACADES[$facade_rel]}"
    FACADE_FILE="$SCRIPTS_DIR/$facade_rel"

    if [[ ! -f "$FACADE_FILE" ]]; then
        echo "⚠️  SKIP: $facade_rel 不存在"
        continue
    fi

    # 跳过动态 re-export facade（无静态声明，无法审计）
    if [[ -n "${DYNAMIC_FACADES[$facade_rel]:-}" ]]; then
        echo "ℹ️  SKIP(dynamic): $facade_rel"
        continue
    fi

    # 1) 提取 facade 已导出的方法名（function Module.Method 或 Module.Method = function）
    EXPORTED=$(grep -oP "(?<=function ${MODULE_NAME}\.)\w+" "$FACADE_FILE" 2>/dev/null || true)
    EXPORTED+=$'\n'
    EXPORTED+=$(grep -oP "(?<=${MODULE_NAME}\.)\w+(?=\s*=)" "$FACADE_FILE" 2>/dev/null || true)

    # 去重排序
    EXPORTED_SORTED=$(echo "$EXPORTED" | sort -u | grep -v '^$' || true)

    # 2) 在项目其他文件中搜索对该模块方法的调用（排除 facade 自身和子目录实现）
    #    模式：ModuleName.MethodName 或 ModuleName:MethodName
    FACADE_DIR=$(dirname "$facade_rel")
    FACADE_BASE=$(basename "$facade_rel" .lua)

    # 搜索所有 .lua 文件中的 Module.Method / Module:Method 调用
    # 排除 facade 自身、其子目录实现、以及 tests/
    CALLERS=$(rg -oIN "${MODULE_NAME}[.:]\w+" "$SCRIPTS_DIR" \
        --glob '*.lua' \
        --glob "!**/${facade_rel}" \
        --glob "!tests/**" \
        2>/dev/null || true)

    # 提取被调用的方法名（去掉 Module. 或 Module: 前缀）
    CALLED_METHODS=$(echo "$CALLERS" | grep -oP "(?<=${MODULE_NAME}[.:])\w+" | sort -u | grep -v '^$' || true)

    # 3) 对比：被调用但未导出的方法
    MISSING=""
    while IFS= read -r method; do
        [[ -z "$method" ]] && continue
        # 跳过私有方法（以 _ 开头的方法只在内部使用）
        [[ "$method" == _* ]] && continue
        # 跳过字段访问（常见的状态字段而非方法）
        if ! echo "$EXPORTED_SORTED" | grep -qx "$method"; then
            # 二次确认：该"method"是否确实是函数调用（后面跟着括号）
            if rg -q "${MODULE_NAME}[.:]${method}\s*\(" "$SCRIPTS_DIR" \
                --glob '*.lua' \
                --glob "!**/${facade_rel}" \
                --glob "!tests/**" 2>/dev/null; then
                MISSING+="    ❌ ${MODULE_NAME}.${method}()"$'\n'
            fi
        fi
    done <<< "$CALLED_METHODS"

    if [[ -n "$MISSING" ]]; then
        echo "══════════════════════════════════════════════════════"
        echo "🚨 ${facade_rel} — 缺失导出："
        echo "$MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 结果汇总
# ─────────────────────────────────────────────────────────────────────────────

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "✅ 全部 ${#FACADES[@]} 个 facade 导出完整，无缺失方法。"
    exit 0
else
    echo "❌ 发现 $ERRORS 个 facade 存在缺失导出，请补充！"
    exit 1
fi
