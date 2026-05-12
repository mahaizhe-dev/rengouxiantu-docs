-- ============================================================================
-- run_all.lua — 统一测试入口
--
-- P0-1: 统一测试入口与最小 CI 门禁
--
-- 用法:
--   lua scripts/tests/run_all.lua               -- 运行所有测试
--   lua scripts/tests/run_all.lua save          -- 只运行 save 组
--   lua scripts/tests/run_all.lua combat        -- 只运行 combat 组
--   lua scripts/tests/run_all.lua regression    -- 只运行 regression 组
--   lua scripts/tests/run_all.lua system        -- 只运行 system 组
--   lua scripts/tests/run_all.lua smoke         -- 只运行 smoke 组
--
-- 退出码:
--   0 — 全部通过（或全部 skip）
--   1 — 有失败
-- ============================================================================

-- 设置 package.path，使 require 能找到 scripts/ 下的模块
package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local TestRegistry = require("tests.TestRegistry")
local TestRunner   = require("tests.TestRunner")

-- 解析命令行参数
local group_filter = arg and arg[1] or nil

-- 打印 banner
print("================================================================")
print("  人狗仙途 — 统一测试 Runner (P0-1)")
print("================================================================")
print("")

-- 获取测试列表
local tests

if group_filter then
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
    print(string.format("Filter: group=%s (%d tests)", group_filter, #tests))
else
    tests = TestRegistry.GetAll()
    print(string.format("Running all tests (%d total)", #tests))
end

print("")

-- 执行
local results = TestRunner.Run(tests)

-- 退出码
print("")
if results.failed > 0 then
    print("EXIT: FAILURE")
    os.exit(1)
else
    print("EXIT: SUCCESS")
    os.exit(0)
end
