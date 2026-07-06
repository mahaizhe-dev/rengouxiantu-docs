-- ============================================================================
-- test_file_budget.lua — 文件长度预算门禁
--
-- 检查 scripts/ 下目标目录中的 Lua 文件是否超出长度预算。
-- 规则来自重构文档 §3：
--   普通代码文件：目标 <= 600 行，警戒 <= 900 行
--   纯数据配置文件：目标 <= 900 行，警戒 <= 1400 行
--
-- 本测试以"警戒线"作为 FAIL 阈值（超出即红灯）。
-- "目标线"超出会产生 WARNING 但不影响门禁结果。
--
-- 覆盖目录：
--   scripts/config/**/*.lua
--   scripts/rendering/**/*.lua
--   scripts/ui/**/*.lua
--   scripts/systems/**/*.lua
-- ============================================================================

local passed = 0
local failed = 0
local warnings = 0
local total = 0

-- ---------------------------------------------------------------------------
-- 配置
-- ---------------------------------------------------------------------------

-- 普通代码文件预算
local CODE_TARGET  = 600   -- 目标线（超出 WARNING）
local CODE_ALERT   = 900   -- 警戒线（超出 FAIL）

-- 纯数据配置文件预算（scripts/config/ 下的文件）
local DATA_TARGET  = 900   -- 目标线
local DATA_ALERT   = 1400  -- 警戒线

-- 要扫描的目录（相对于 scripts/）
local SCAN_DIRS = {
    "config",
    "rendering",
    "ui",
    "systems",
}

-- 特殊豁免列表：已知超标、将在后续阶段拆分的文件
-- key = 相对于 scripts/ 的路径, value = 当前允许的最大行数（棘轮上限）
-- 棘轮策略：当前行数 + 50 行缓冲，防止进一步膨胀
-- 拆分完成后从此表移除，即受普通预算约束
local EXEMPTIONS = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- 第一梯队：不可再拆的 ratchet（保留监控）
    -- ═══════════════════════════════════════════════════════════════════════
    -- [已毕业] config/MonsterData.lua — 193 行 facade，Step 4 拆分
    -- [已毕业] config/EquipmentData.lua — 252 行 facade，Step 3 拆分
    -- [已毕业] config/EquipmentData_Special.lua — 20 行 facade，Step 4C 拆分
    -- [已毕业] config/MonsterTypes_ch3.lua — 11 行 facade，Step 4B 拆分
    -- [已毕业] rendering/EffectRenderer.lua — 206 行 facade，Step 5 拆分
    -- [已毕业] rendering/TileRenderer.lua — 270 行 facade，Step 5 拆分
    -- [已毕业] rendering/EntityRenderer.lua — 24 行 facade，Step 5 拆分
    ["rendering/effects/skills_b.lua"] = 950,   -- 当前 906（9个技能渲染器，单函数不可再拆）
    ["rendering/entities/monsters.lua"]= 1050,  -- 当前 1013（4个怪物渲染函数，紧耦合不可拆）
    ["ui/PetPanel.lua"]                = 2225,  -- 当前 2175

    -- ═══════════════════════════════════════════════════════════════════════
    -- 第二梯队：超警戒线，不在本轮范围，后续迭代处理
    -- ═══════════════════════════════════════════════════════════════════════
    -- config/
    -- [已毕业] config/GameConfig.lua — 755 行，已在 DATA_TARGET(900) 内，Step 2 移除
    ["config/MonsterTypes_ch5.lua"]    = 1000,  -- 当前 940

    -- rendering/
    ["rendering/DecoDivine.lua"]       = 1450,  -- 当前 1398

    -- systems/
    -- [已毕业] systems/SkillSystem.lua — 443 行 facade，Step 6A 拆分
    -- [已毕业] systems/LootSystem.lua — 54 行 facade，Step 6B 拆分
    -- [已毕业] systems/ChallengeSystem.lua — 428 行 facade，Step 6D 拆分
    -- [已毕业] systems/InventorySystem.lua — 361 行 facade，Step 6C 拆分
    ["systems/AtlasSystem.lua"]        = 1265,  -- 当前 1215
    ["systems/CombatSystem.lua"]       = 1090,  -- 当前 1038
    ["systems/QuestSystem.lua"]        = 1105,  -- 当前 1055
    ["systems/save/SaveMigrations.lua"]= 1165,  -- 当前 1111

    -- ui/
    ["ui/AlchemyUI.lua"]               = 1940,  -- 当前 1891
    ["ui/ArtifactUI.lua"]              = 955,   -- 当前 902
    ["ui/ArtifactUI_ch4.lua"]          = 1010,  -- 当前 957
    ["ui/ArtifactUI_ch5.lua"]          = 955,   -- 当前 904
    ["ui/AtlasUI.lua"]                 = 1370,  -- 当前 1317
    ["ui/BlackMerchantUI.lua"]         = 1825,  -- 当前 1775
    ["ui/BottomBar.lua"]               = 1130,  -- 当前 1078
    ["ui/BulletinUI.lua"]              = 1455,  -- 当前 1405
    ["ui/ChallengeUI.lua"]             = 2200,  -- 当前 2143
    ["ui/CharacterSelectScreen.lua"]   = 1285,  -- 当前 1231
    ["ui/CharacterUI.lua"]             = 1730,  -- 当前 1679
    ["ui/DaoQuestionUI.lua"]           = 1005,  -- 当前 954
    ["ui/DragonForgeUI.lua"]           = 1690,  -- 当前 1639
    ["ui/EquipTooltip.lua"]            = 1075,  -- 当前 1024
    ["ui/EventExchangeUI.lua"]         = 1605,  -- 当前 1551
    ["ui/GMConsole.lua"]               = 1535,  -- 当前 1485
    ["ui/GourdUI.lua"]                 = 1155,  -- 当前 1103
    ["ui/LeaderboardUI.lua"]           = 1380,  -- 当前 1331
    ["ui/Minimap.lua"]                 = 1621,  -- 当前 1571
    ["ui/NPCDialog.lua"]               = 1005,  -- 当前 955
    ["ui/QuestRewardUI.lua"]           = 1055,  -- 当前 1005
    ["ui/SwordForgeUI.lua"]            = 1540,  -- 当前 1486
    ["ui/SystemMenu.lua"]              = 1575,  -- 当前 1524
    ["ui/TemperUI.lua"]                = 1110,  -- 当前 1058
}

-- ---------------------------------------------------------------------------
-- 工具函数
-- ---------------------------------------------------------------------------

--- 计算文件行数
---@param filepath string 绝对路径
---@return integer|nil lineCount 行数，读取失败返回 nil
local function countLines(filepath)
    local f = io.open(filepath, "r")
    if not f then return nil end
    local count = 0
    for _ in f:lines() do
        count = count + 1
    end
    f:close()
    return count
end

--- 递归扫描目录下的 .lua 文件
--- 兼容 lupa 环境（io.popen 不可用），使用 os.execute + 临时文件
---@param dir string 目录路径（相对或绝对）
---@return string[] files 文件路径列表
local function scanLuaFiles(dir)
    local files = {}
    local tmpfile = os.tmpname()
    -- 使用 find 列出所有 .lua 文件，结果写入临时文件
    local cmd = string.format(
        'find "%s" -name "*.lua" -type f > "%s" 2>/dev/null',
        dir, tmpfile
    )
    os.execute(cmd)
    local f = io.open(tmpfile, "r")
    if f then
        for line in f:lines() do
            if line and #line > 0 then
                files[#files + 1] = line
            end
        end
        f:close()
    end
    os.remove(tmpfile)
    return files
end

--- 判断文件是否为纯数据配置文件
---@param relPath string 相对于 scripts/ 的路径
---@return boolean
local function isDataFile(relPath)
    return relPath:find("^config/") ~= nil
end

-- ---------------------------------------------------------------------------
-- 主逻辑
-- ---------------------------------------------------------------------------

-- scripts/ 目录路径（相对于项目根 cwd）
-- run_all.lua / _run_via_lupa.py 执行时 cwd 保证为项目根
local scriptsDir = "scripts"

local results = {}  -- {relPath, lines, status, limit}

for _, subdir in ipairs(SCAN_DIRS) do
    local fullDir = scriptsDir .. "/" .. subdir
    local files = scanLuaFiles(fullDir)

    for _, filepath in ipairs(files) do
        -- 计算相对路径（相对于 scripts/）
        -- filepath 形如 "scripts/config/xxx.lua"，去掉 "scripts/" 前缀
        local relPath = filepath:sub(#scriptsDir + 2)

        -- 跳过测试文件本身
        if relPath:find("^tests/") then goto continue end

        local lines = countLines(filepath)
        if not lines then goto continue end

        total = total + 1

        -- 确定预算
        local target, alert
        if isDataFile(relPath) then
            target = DATA_TARGET
            alert  = DATA_ALERT
        else
            target = CODE_TARGET
            alert  = CODE_ALERT
        end

        -- 检查豁免
        local exemptLimit = EXEMPTIONS[relPath]
        if exemptLimit then
            -- 豁免文件：只检查是否超出豁免上限（防止进一步膨胀）
            if lines > exemptLimit then
                failed = failed + 1
                results[#results + 1] = {
                    relPath = relPath,
                    lines   = lines,
                    status  = "FAIL_EXEMPT_EXCEEDED",
                    limit   = exemptLimit,
                }
            else
                passed = passed + 1
                results[#results + 1] = {
                    relPath = relPath,
                    lines   = lines,
                    status  = "EXEMPT",
                    limit   = exemptLimit,
                }
            end
        elseif lines > alert then
            -- 超过警戒线 → FAIL
            failed = failed + 1
            results[#results + 1] = {
                relPath = relPath,
                lines   = lines,
                status  = "FAIL",
                limit   = alert,
            }
        elseif lines > target then
            -- 超过目标线 → WARNING（不 FAIL）
            warnings = warnings + 1
            passed = passed + 1
            results[#results + 1] = {
                relPath = relPath,
                lines   = lines,
                status  = "WARNING",
                limit   = target,
            }
        else
            passed = passed + 1
        end

        ::continue::
    end
end

-- ---------------------------------------------------------------------------
-- 输出报告
-- ---------------------------------------------------------------------------

print("=" .. string.rep("=", 69))
print("  FILE BUDGET GATE — 文件长度预算门禁")
print("=" .. string.rep("=", 69))
print("")
print(string.format("  扫描目录: %s", table.concat(SCAN_DIRS, ", ")))
print(string.format("  代码文件: 目标 %d 行 / 警戒 %d 行", CODE_TARGET, CODE_ALERT))
print(string.format("  数据文件: 目标 %d 行 / 警戒 %d 行", DATA_TARGET, DATA_ALERT))
print("")

-- 输出失败项
local failItems = {}
local warnItems = {}
local exemptItems = {}

for _, r in ipairs(results) do
    if r.status == "FAIL" or r.status == "FAIL_EXEMPT_EXCEEDED" then
        failItems[#failItems + 1] = r
    elseif r.status == "WARNING" then
        warnItems[#warnItems + 1] = r
    elseif r.status == "EXEMPT" then
        exemptItems[#exemptItems + 1] = r
    end
end

if #failItems > 0 then
    print("  ❌ FAIL（超过警戒线 / 超过豁免上限）:")
    for _, r in ipairs(failItems) do
        print(string.format("     %s: %d 行 (限制 %d)", r.relPath, r.lines, r.limit))
    end
    print("")
end

if #warnItems > 0 then
    print("  ⚠️  WARNING（超过目标线，未超警戒线）:")
    for _, r in ipairs(warnItems) do
        print(string.format("     %s: %d 行 (目标 %d)", r.relPath, r.lines, r.limit))
    end
    print("")
end

if #exemptItems > 0 then
    print(string.format("  📋 豁免文件: %d 个（待后续阶段拆分）", #exemptItems))
    for _, r in ipairs(exemptItems) do
        print(string.format("     %s: %d 行 (豁免 %d)", r.relPath, r.lines, r.limit))
    end
    print("")
end

print(string.format("  总计: %d 文件 | ✅ %d PASS | ❌ %d FAIL | ⚠️  %d WARNING",
    total, passed, failed, warnings))
print("")

if failed > 0 then
    print("  结论: ❌ FAIL — 有文件超出预算限制")
else
    print("  结论: ✅ PASS — 所有文件在预算范围内")
end
print("")

return { passed = passed, failed = failed, total = total }
