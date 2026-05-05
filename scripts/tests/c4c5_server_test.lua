-- ============================================================================
-- c4c5_server_test.lua — C4(Money.Cost) + C5(BatchCommit原子回滚) 验证
-- ============================================================================
-- 运行环境: 服务端 (UrhoXServer)
-- 触发方式: GM控制台 "C4C5 API验证" 按钮 → C2S_ServerApiTest → 服务端执行
--
-- 测试计划:
--   Phase 1 — C4: Money.Cost
--     T1: Money.Add(1000)             → ok
--     T2: Money.Get                   → 余额=1000
--     T3: Money.Cost(300)             → ok
--     T4: Money.Get                   → 余额=700
--     T5: Money.Cost(9999)            → error(余额不足)
--     T6: Money.Get                   → 余额仍=700(未扣)
--     T7: Money.Cost(700)             → ok(精确扣完)
--     T8: Money.Get                   → 余额=0
--
--   Phase 2 — C5: BatchCommit 原子性
--     T9:  BatchCommit{MoneyAdd500, ScoreSet"before"}  → ok
--     T10: Verify Money=500, Score.v="before"
--     T11: BatchCommit{MoneyCost99999, ScoreSet"ROLLBACK"} → error
--     T12: Verify Money仍=500, Score.v仍="before"(原子回滚)
--     T13: BatchCommit{MoneyCost100, ScoreSet"after"}  → ok
--     T14: Verify Money=400, Score.v="after"
-- ============================================================================

local M = {}

local MONEY_KEY = "_c4c5_test_gold"
local SCORE_KEY = "_c5_test_marker"

--- 运行完整 C4/C5 验证
---@param sCloud any        serverCloud 实例
---@param userId integer    测试用户 ID
---@param onComplete fun(passed:integer, failed:integer, log:string)
function M.Run(sCloud, userId, onComplete)
    local passed = 0
    local failed = 0
    local logs = {}

    local function log(msg)
        logs[#logs + 1] = msg
        print("[C4C5] " .. msg)
    end

    local function pass(tag, detail)
        passed = passed + 1
        log("PASS " .. tag .. (detail and (" — " .. detail) or ""))
    end

    local function fail(tag, detail)
        failed = failed + 1
        log("FAIL " .. tag .. (detail and (" — " .. detail) or ""))
    end

    local function finish()
        log(string.format("== 结果: %d 通过, %d 失败 / %d 总计 ==",
            passed, failed, passed + failed))
        onComplete(passed, failed, table.concat(logs, "\n"))
    end

    -- Step-based async chain
    local steps = {}
    local si = 0
    local function next()
        si = si + 1
        if si <= #steps then
            steps[si]()
        else
            finish()
        end
    end

    local uid = userId

    -- ================================================================
    -- Phase 0: 清理
    -- ================================================================
    steps[#steps + 1] = function()
        log("-- Phase 0: 清理测试数据 --")
        sCloud:Delete(uid, SCORE_KEY)
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal > 0 then
                    sCloud.money:Cost(uid, MONEY_KEY, bal, {
                        ok = function()
                            log("清理: Cost(" .. bal .. ") 余额归零")
                            next()
                        end,
                        error = function(_, reason)
                            log("清理: Cost失败(" .. tostring(reason) .. "), 继续")
                            next()
                        end,
                    })
                else
                    log("清理: 余额已为0")
                    next()
                end
            end,
            error = function(_, reason)
                log("清理: Money.Get失败(" .. tostring(reason) .. "), 继续")
                next()
            end,
        })
    end

    -- ================================================================
    -- Phase 1: C4 — Money.Cost 验证
    -- ================================================================

    -- C4-T1: Money.Add 1000
    steps[#steps + 1] = function()
        log("-- Phase 1: C4 Money.Cost 验证 --")
        sCloud.money:Add(uid, MONEY_KEY, 1000, {
            ok = function()
                pass("C4-T1", "Money.Add(1000) 成功")
                next()
            end,
            error = function(code, reason)
                fail("C4-T1", "Money.Add(1000) 失败: code=" .. tostring(code)
                    .. " reason=" .. tostring(reason))
                next()
            end,
        })
    end

    -- C4-T2: Get → 余额=1000
    steps[#steps + 1] = function()
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal == 1000 then
                    pass("C4-T2", "余额=1000")
                else
                    fail("C4-T2", "期望1000, 实际=" .. tostring(bal))
                end
                next()
            end,
            error = function(code, reason)
                fail("C4-T2", "Get失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C4-T3: Cost 300 → 应成功
    steps[#steps + 1] = function()
        sCloud.money:Cost(uid, MONEY_KEY, 300, {
            ok = function()
                pass("C4-T3", "Cost(300) ok回调触发")
                next()
            end,
            error = function(code, reason)
                fail("C4-T3", "Cost(300) 应成功但error: code=" .. tostring(code)
                    .. " reason=" .. tostring(reason))
                next()
            end,
        })
    end

    -- C4-T4: Get → 余额=700
    steps[#steps + 1] = function()
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal == 700 then
                    pass("C4-T4", "Cost后余额=700")
                else
                    fail("C4-T4", "期望700, 实际=" .. tostring(bal))
                end
                next()
            end,
            error = function(code, reason)
                fail("C4-T4", "Get失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C4-T5: Cost 9999 → 应失败(余额不足)
    steps[#steps + 1] = function()
        sCloud.money:Cost(uid, MONEY_KEY, 9999, {
            ok = function()
                fail("C4-T5", "Cost(9999) 应失败但返回ok — 余额不足未被拒绝!")
                next()
            end,
            error = function(code, reason)
                pass("C4-T5", "Cost(9999) 余额不足被拒绝, code="
                    .. tostring(code) .. " reason=" .. tostring(reason))
                next()
            end,
        })
    end

    -- C4-T6: Get → 余额仍=700(未扣)
    steps[#steps + 1] = function()
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal == 700 then
                    pass("C4-T6", "拒绝后余额仍=700(未扣款)")
                else
                    fail("C4-T6", "期望700(不变), 实际=" .. tostring(bal))
                end
                next()
            end,
            error = function(code, reason)
                fail("C4-T6", "Get失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C4-T7: Cost 700 → 精确扣完
    steps[#steps + 1] = function()
        sCloud.money:Cost(uid, MONEY_KEY, 700, {
            ok = function()
                pass("C4-T7", "Cost(700) 精确扣完")
                next()
            end,
            error = function(code, reason)
                fail("C4-T7", "Cost(700) 应成功但error: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C4-T8: Get → 余额=0
    steps[#steps + 1] = function()
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal == 0 then
                    pass("C4-T8", "余额=0")
                else
                    fail("C4-T8", "期望0, 实际=" .. tostring(bal))
                end
                next()
            end,
            error = function(code, reason)
                fail("C4-T8", "Get失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- ================================================================
    -- Phase 2: C5 — BatchCommit 原子性验证
    -- ================================================================

    -- C5-T9: Setup: BatchCommit { MoneyAdd 500, ScoreSet "before" }
    steps[#steps + 1] = function()
        log("-- Phase 2: C5 BatchCommit 原子性验证 --")
        local c = sCloud:BatchCommit("C5 setup")
        c:MoneyAdd(uid, MONEY_KEY, 500)
        c:ScoreSet(uid, SCORE_KEY, { v = "before" })
        c:Commit({
            ok = function()
                pass("C5-T9", "BatchCommit(Add500+ScoreSet) 成功")
                next()
            end,
            error = function(code, reason)
                fail("C5-T9", "BatchCommit setup失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C5-T10: Verify Money=500, Score.v="before"
    steps[#steps + 1] = function()
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal == 500 then
                    pass("C5-T10a", "Money=500")
                else
                    fail("C5-T10a", "期望500, 实际=" .. tostring(bal))
                end
                sCloud:Get(uid, SCORE_KEY, {
                    ok = function(scores)
                        local sv = scores and scores[SCORE_KEY]
                        if sv and sv.v == "before" then
                            pass("C5-T10b", "Score.v='before'")
                        else
                            fail("C5-T10b", "期望'before', 实际="
                                .. tostring(sv and sv.v))
                        end
                        next()
                    end,
                    error = function(_, reason)
                        fail("C5-T10b", "Score.Get失败: " .. tostring(reason))
                        next()
                    end,
                })
            end,
            error = function(_, reason)
                fail("C5-T10a", "Money.Get失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C5-T11: 原子失败: BatchCommit { MoneyCost 99999, ScoreSet "ROLLBACK" }
    steps[#steps + 1] = function()
        local c = sCloud:BatchCommit("C5 atomic failure")
        c:MoneyCost(uid, MONEY_KEY, 99999)  -- 余额只有 500, 应失败
        c:ScoreSet(uid, SCORE_KEY, { v = "SHOULD_ROLLBACK" })
        c:Commit({
            ok = function()
                fail("C5-T11", "BatchCommit应失败(余额不足)但返回ok — 原子性存疑!")
                next()
            end,
            error = function(code, reason)
                pass("C5-T11", "BatchCommit余额不足被拒绝, code=" .. tostring(code))
                next()
            end,
        })
    end

    -- C5-T12: 回滚验证: Money仍=500, Score.v仍="before"
    steps[#steps + 1] = function()
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal == 500 then
                    pass("C5-T12a", "Money回滚: 仍=500(未扣)")
                else
                    fail("C5-T12a", "Money回滚失败! 期望500, 实际=" .. tostring(bal))
                end
                sCloud:Get(uid, SCORE_KEY, {
                    ok = function(scores)
                        local sv = scores and scores[SCORE_KEY]
                        if sv and sv.v == "before" then
                            pass("C5-T12b", "Score回滚: 仍='before'(未覆写)")
                        else
                            fail("C5-T12b", "Score回滚失败! 期望'before', 实际='"
                                .. tostring(sv and sv.v) .. "'")
                        end
                        next()
                    end,
                    error = function(_, reason)
                        fail("C5-T12b", "Score.Get失败: " .. tostring(reason))
                        next()
                    end,
                })
            end,
            error = function(_, reason)
                fail("C5-T12a", "Money.Get失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C5-T13: 正常成功: BatchCommit { MoneyCost 100, ScoreSet "after" }
    steps[#steps + 1] = function()
        local c = sCloud:BatchCommit("C5 normal success")
        c:MoneyCost(uid, MONEY_KEY, 100)
        c:ScoreSet(uid, SCORE_KEY, { v = "after" })
        c:Commit({
            ok = function()
                pass("C5-T13", "BatchCommit(Cost100+ScoreSet'after') 成功")
                next()
            end,
            error = function(code, reason)
                fail("C5-T13", "BatchCommit应成功但失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- C5-T14: Verify Money=400, Score.v="after"
    steps[#steps + 1] = function()
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal == 400 then
                    pass("C5-T14a", "Money=400(500-100)")
                else
                    fail("C5-T14a", "期望400, 实际=" .. tostring(bal))
                end
                sCloud:Get(uid, SCORE_KEY, {
                    ok = function(scores)
                        local sv = scores and scores[SCORE_KEY]
                        if sv and sv.v == "after" then
                            pass("C5-T14b", "Score.v='after'")
                        else
                            fail("C5-T14b", "期望'after', 实际='"
                                .. tostring(sv and sv.v) .. "'")
                        end
                        next()
                    end,
                    error = function(_, reason)
                        fail("C5-T14b", "Score.Get失败: " .. tostring(reason))
                        next()
                    end,
                })
            end,
            error = function(_, reason)
                fail("C5-T14a", "Money.Get失败: " .. tostring(reason))
                next()
            end,
        })
    end

    -- ================================================================
    -- Phase 3: 清理
    -- ================================================================
    steps[#steps + 1] = function()
        log("-- Phase 3: 清理测试数据 --")
        sCloud:Delete(uid, SCORE_KEY)
        -- Cost 剩余 400 归零
        sCloud.money:Get(uid, {
            ok = function(moneys)
                local bal = (moneys and moneys[MONEY_KEY]) or 0
                if bal > 0 then
                    sCloud.money:Cost(uid, MONEY_KEY, bal, {
                        ok = function()
                            log("清理: 余额归零完成")
                            next()
                        end,
                        error = function()
                            log("清理: Cost失败, 忽略")
                            next()
                        end,
                    })
                else
                    log("清理: 余额已为0")
                    next()
                end
            end,
            error = function()
                log("清理: Get失败, 忽略")
                next()
            end,
        })
    end

    -- Start
    log("======================================")
    log("  C4/C5 serverCloud API 验证测试")
    log("  userId=" .. tostring(uid))
    log("  MoneyKey=" .. MONEY_KEY)
    log("  ScoreKey=" .. SCORE_KEY)
    log("======================================")
    next()
end

return M
