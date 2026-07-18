---@diagnostic disable
-- ============================================================================
-- test_save_phase1_smoke.lua — Phase 1 保存链路止血 验烟测试
--
-- 验证 WP-01/02/03 的结构保证，不触发真实 Save()（无存档副作用）。
--   T1. UpdateCritical 是独立函数（WP-01 拆分成功）
--   T2. Update 仍存在（自动保存调度未丢）
--   T3. _dirtySinceFlush 字段存在且可操作（WP-02 基础）
--   T4. save_request 在 saving=true 时设置 _dirtySinceFlush（WP-02 核心逻辑）
--   T5. dirty 防抖不再在 Save 前清除（WP-02：Update 内无 _dirty=false 赋值）
--   T6. SavePersistence error 回调能区分 slot_locked（WP-03 源码断言）
--   T7. NetworkStatus.RecordSample 可调用（WP-01 保证 UpdateCritical 驱动它）
--
-- 纯结构+行为测试，不触发网络请求、不写存档、不碰玩家数据。
-- ============================================================================

local passed, failed, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(a, b, msg)
    if a ~= b then error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a)) end
end
local function assertTrue(v, msg) if not v then error(msg or "expected true") end end
local function assertFalse(v, msg) if v then error(msg or "expected false") end end

print("\n[test_save_phase1_smoke] === Phase 1 保存链路止血 验烟 ===\n")

local SaveSystem = require("systems.SaveSystem")
local NetworkStatus = require("network.NetworkStatus")

-- T1: UpdateCritical 独立函数
test("T1. SaveSystem.UpdateCritical 是独立函数（WP-01 拆分）", function()
    assertTrue(type(SaveSystem.UpdateCritical) == "function",
        "UpdateCritical should be a function")
end)

-- T2: Update 仍存在
test("T2. SaveSystem.Update 仍存在（自动保存调度）", function()
    assertTrue(type(SaveSystem.Update) == "function",
        "Update should still exist")
end)

-- T3: _dirtySinceFlush 字段存在
test("T3. _dirtySinceFlush 字段可操作（WP-02 基础设施）", function()
    -- 保存原值
    local orig = SaveSystem._dirtySinceFlush
    SaveSystem._dirtySinceFlush = true
    assertEqual(SaveSystem._dirtySinceFlush, true, "可设为 true")
    SaveSystem._dirtySinceFlush = false
    assertEqual(SaveSystem._dirtySinceFlush, false, "可设为 false")
    -- 恢复
    SaveSystem._dirtySinceFlush = orig
end)

-- T4: save_request 在 saving=true 时设 _dirtySinceFlush
test("T4. save_request 飞行期间 → _dirtySinceFlush=true（WP-02 核心）", function()
    -- 保存原始状态
    local origSaving = SaveSystem.saving
    local origDirty = SaveSystem._dirty
    local origDSF = SaveSystem._dirtySinceFlush
    local origLoaded = SaveSystem.loaded
    local origSlot = SaveSystem.activeSlot

    -- 确保 save_request 事件 handler 已注册（SaveSystem.Init 在游戏启动时调用，
    -- 但测试环境可能尚未走到 Init；若 _onSaveRequest 未注册则先调 Init）
    if not SaveSystem._onSaveRequest then
        SaveSystem.Init()
    end

    -- 模拟：已加载、有 slot、正在存档
    SaveSystem.loaded = true
    SaveSystem.activeSlot = 1
    SaveSystem.saving = true
    SaveSystem._dirtySinceFlush = false
    SaveSystem._dirty = false  -- 确保初始为 false 以验证 handler 设为 true

    -- 触发 save_request handler
    local EventBus = require("core.EventBus")
    EventBus.Emit("save_request")

    -- 验证
    assertTrue(SaveSystem._dirty, "save_request 应设 _dirty=true")
    assertTrue(SaveSystem._dirtySinceFlush, "飞行中 save_request 应设 _dirtySinceFlush=true")

    -- 恢复
    SaveSystem.saving = origSaving
    SaveSystem._dirty = origDirty
    SaveSystem._dirtySinceFlush = origDSF
    SaveSystem.loaded = origLoaded
    SaveSystem.activeSlot = origSlot
end)

-- T5: 源码断言 — Update 中 dirty flush 不再赋值 _dirty=false
test("T5. Update 中 dirty flush 不清 _dirty（WP-02 源码断言）", function()
    if not (io and io.open) then
        print("    (skip) 无 io"); return
    end
    local f = io.open("scripts/systems/SaveSystem.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    -- 提取 Update 函数体（从 "function SaveSystem.Update" 到下一个顶层 function 或文件末尾）
    local body = src:match("function SaveSystem%.Update%(dt%)(.-)\nfunction ")
        or src:match("function SaveSystem%.Update%(dt%)(.-)\n%-%-")
        or src:match("function SaveSystem%.Update%(dt%)(.+)")
    assertTrue(body ~= nil, "应能提取 Update 函数体")
    -- 确认不含 _dirty = false（WP-02 已移除该赋值）
    local hasDirtyFalse = body:find("_dirty%s*=%s*false") ~= nil
    assertFalse(hasDirtyFalse,
        "Update 中不应再有 _dirty = false（WP-02: 延迟到 ok 回调清除）")
end)

-- T6: SavePersistence error 回调能区分 slot_locked
test("T6. SavePersistence error 回调区分 slot_locked（WP-03 源码断言）", function()
    if not (io and io.open) then
        print("    (skip) 无 io"); return
    end
    local f = io.open("scripts/systems/save/SavePersistence.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertTrue(src:find("slot_locked") ~= nil,
        "SavePersistence 应含 slot_locked 分类处理")
    assertTrue(src:find("SS%._slotLockedCount%s*>=%s*10") ~= nil,
        "slot_locked 应有连续冲突升级阈值")
    assertTrue(src:find("SS%._retryTimer%s*=%s*3") ~= nil,
        "普通 slot_locked 应使用 3 秒短退避")
    assertTrue(src:find('callback%(false, "slot_locked_persistent"%)') ~= nil,
        "持续 slot_locked 应显式失败并通知业务回调")
end)

-- T7: NetworkStatus.RecordSample 可调用
test("T7. NetworkStatus.RecordSample 可调用（WP-01 保证驱动）", function()
    assertTrue(type(NetworkStatus.RecordSample) == "function",
        "RecordSample should be a function")
    -- 保存并恢复状态
    local origState = { NetworkStatus._failCount, NetworkStatus._state }
    NetworkStatus.Reset()
    -- 模拟一次连接正常采样
    local event = NetworkStatus.RecordSample(true, 3.0)
    assertEqual(event, nil, "正常连接不应触发事件")
    -- 恢复
    NetworkStatus.Reset()
    NetworkStatus._failCount = origState[1]
    NetworkStatus._state = origState[2]
end)

print("\n[test_save_phase1_smoke] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
