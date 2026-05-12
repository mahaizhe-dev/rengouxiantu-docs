-- ============================================================================
-- run_all.lua — 统一测试入口
--
-- P0-1:  统一测试入口与最小 CI 门禁
-- P0-1A: 测试门禁收口与运行环境固化
--
-- 用法:
--   lua scripts/tests/run_all.lua               -- 默认门禁（仅 blocking）
--   lua scripts/tests/run_all.lua --all         -- 运行所有测试
--   lua scripts/tests/run_all.lua --gate=blocking     -- 指定 gate 类型
--   lua scripts/tests/run_all.lua --gate=non_blocking -- 指定 gate 类型
--   lua scripts/tests/run_all.lua --gate=known_red    -- 指定 gate 类型
--   lua scripts/tests/run_all.lua save           -- 只运行 save 组
--   lua scripts/tests/run_all.lua combat          -- 只运行 combat 组
--   lua scripts/tests/run_all.lua smoke           -- 只运行 smoke 组
--
-- 退出码:
--   0 — 全部通过（且有实际执行）
--   1 — 有失败
--   2 — 无有效执行（全部 skip 或空集合）
-- ============================================================================

-- 设置 package.path，使 require 能找到 scripts/ 下的模块
package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local TestRegistry = require("tests.TestRegistry")
local TestRunner   = require("tests.TestRunner")

-- 解析命令行参数
local raw_arg = arg and arg[1] or nil
local run_mode = "blocking"  -- 默认只跑 blocking
local group_filter = nil
local gate_filter = nil

if raw_arg == "--all" then
    run_mode = "all"
elseif raw_arg and raw_arg:match("^%-%-gate=(.+)$") then
    gate_filter = raw_arg:match("^%-%-gate=(.+)$")
    run_mode = "gate"
elseif raw_arg then
    group_filter = raw_arg
    run_mode = "group"
end

-- 打印 banner
print("================================================================")
print("  人狗仙途 — 统一测试 Runner (P0-1A)")
print("================================================================")
print("")

-- 获取测试列表
local tests
local label

if run_mode == "all" then
    tests = TestRegistry.GetAll()
    label = string.format("ALL tests (%d total)", #tests)

elseif run_mode == "gate" then
    tests = TestRegistry.GetByGate(gate_filter)
    if #tests == 0 then
        print(string.format("ERROR: 未找到 gate '%s' 的测试", gate_filter))
        print("")
        print("可用 gate: blocking, non_blocking, known_red")
        os.exit(1)
    end
    label = string.format("Gate: %s (%d tests)", gate_filter, #tests)

elseif run_mode == "group" then
    tests = TestRegistry.GetByGroup(group_filter)
    if #tests == 0 then
        print(string.format("ERROR: 未找到 group '%s' 的测试", group_filter))
        print("")
        print("可用 group:")
        local groups = TestRegistry.GetGroups()
        for _, g in ipairs(groups) do
            print("  - " .. g)
        end
        os.exit(1)
    end
    label = string.format("Group: %s (%d tests)", group_filter, #tests)

else
    -- 默认: blocking 门禁
    tests = TestRegistry.GetBlocking()
    label = string.format("BLOCKING gate (%d tests)", #tests)
end

print(label)
print("")

-- 执行
local results = TestRunner.Run(tests)

-- 退出码判定（P0-1A 新增：空执行检测）
print("")

local executed = results.passed + results.failed

if results.failed > 0 then
    print("EXIT: FAILURE")
    os.exit(1)
elseif executed == 0 then
    print("[EMPTY] 无有效执行的测试（全部 skip 或集合为空），不视为成功")
    print("EXIT: EMPTY (no coverage)")
    os.exit(2)
else
    print("EXIT: SUCCESS")
    os.exit(0)
end
