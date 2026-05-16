# 2026-05-14 BM-HOTFIX-SELL-01 黑市卖出快速恢复 — 完成报告

## 1. 任务卡原文

见 `docs/2026-05-14-BM-HOTFIX-SELL-01-黑市卖出快速恢复任务卡.md`

## 2. 评估结论

BM-FIX-01 完成后，卡片级 `canSell` 已不受 `global_unsync`（L2）影响，但 **onClick 和 confirm 两处仍保留 L2 拦截分支**，导致整市场在 L2 脏时"看起来能卖、但点击后被挡"。

HOTFIX-SELL-01 的目标：**彻底移除 L2 在卖出流程中的拦截，仅保留 L1（locked_item）作为唯一阻断条件。**

---

## 3. 代码变更

### 3.1 `scripts/ui/BlackMerchantUI.lua`（2 处修改）

#### A. onClick 卖出按钮（原 L622-631）

```diff
 if curReason == "locked_item" then
     SetStatus(TradeLock.LOCK_MESSAGE, C.textError, 3)
     print("[BlackMerchantUI] SELL BTN BLOCKED (L1): " .. tostring(curDetail))
     return
-elseif curReason == "global_unsync" then
-    SetStatus("背包数据未同步，请稍后再试", C.textError, 3)
-    print("[BlackMerchantUI] SELL BTN BLOCKED (L2): " .. tostring(curDetail))
-    return
 end
+-- HOTFIX-SELL-01: global_unsync(L2) 不再阻止卖出按钮，仅 locked_item(L1) 拦截
```

#### B. confirm 确认弹窗（原 L386-395）

```diff
 if cfmReason == "locked_item" then
     SetStatus(TradeLock.LOCK_MESSAGE, C.textError, 3)
     print("[BlackMerchantUI] CONFIRM BLOCKED (L1): " .. tostring(cfmDetail))
     return
-elseif cfmReason == "global_unsync" then
-    SetStatus("背包数据未同步，请稍后再试", C.textError, 3)
-    print("[BlackMerchantUI] CONFIRM BLOCKED (L2): " .. tostring(cfmDetail))
-    return
 end
+-- HOTFIX-SELL-01: global_unsync(L2) 不再阻止确认卖出，仅 locked_item(L1) 拦截
```

### 3.2 未修改的文件

- `BlackMarketSyncState.lua` — `GetSellBlockReason()` 和 `IsBlocked()` 底层 API 不变，仍然返回 `"global_unsync"`。只是 UI 调用方不再以此拦截卖出。
- `BlackMerchantHandler.lua` — 服务端逻辑不受影响。

---

## 4. 测试变更

### 4.1 更新的测试文件

#### `test_bm_fix01_card_sell_split.lua`

- `simulateOnClickBlock` / `simulateConfirmBlock` 两个模拟函数移除了 L2 分支，与 UI 代码保持一致
- P2-2: `onClick 被 L2 拦截` → `onClick 不再被 L2 拦截，放行`
- P2-3: `确认弹窗被 L2 拦截` → `确认弹窗不再被 L2 拦截，放行`
- P2-4: `B 的 onClick 被 L2 拦截` → `B 的 onClick 不再被 L2 拦截`
- P2-5: `SaveSession 脏 → onClick 拦截` → `SaveSession 脏 → onClick 也不拦截`
- P3-4: `未锁商品的 onClick 都被 L2 拦截` → `未锁商品的 onClick 不再被 L2 拦截`
- P4-3: `onClick 多层防线 L1→L2→放行` → `onClick 仅 L1 拦截 L1→L2放行→全清放行`
- P4-4: `确认弹窗 L1→L2→放行` → `确认弹窗仅 L1 拦截 L1→L2放行→全清放行`

#### `test_pre_c5a1_three_lines.lua`

- T5: 更新注释 — `GetSellBlockReason` 底层仍返回 `global_unsync`（API 行为不变），但 onClick/confirm 不再以此拦截卖出
- T6: 更新注释 — `IsBlocked` 底层 API 行为不变

### 4.2 未修改的测试文件

- `test_bm_s4e_sell_block_consistency.lua` — 测试底层 `GetSellBlockReason` / `IsBlocked` API，这些 API 没有改动，测试无需变更

---

## 5. 必测路径验证（§7）

### 路径 1: 买入 A 后，A 显示🔒锁定

- P1-1: `A 锁住 → 卡片显示🔒锁定，canSell=false` ✅
- P4-1: `GetSellBlockReason 对锁定商品返回 locked_item` ✅

### 路径 2: A 锁住时，B/C 未锁商品可正常卖出

- P1-2: `B 未锁 → 卡片显示出售，canSell=true` ✅
- **P2-2: `HOTFIX-SELL-01: L2 脏 → onClick 不再拦截，放行`** ✅
- **P2-3: `HOTFIX-SELL-01: L2 脏 → 确认弹窗不再拦截，放行`** ✅
- P2-4: `L2 脏 + A 锁住 → A🔒锁定, B 出售, B 的 onClick 不再被 L2 拦截` ✅

### 路径 3: A 保存后解锁，A 本身也恢复可卖

- P4-2: `game_saved → 锁清除 → 商品恢复可售` ✅

### 路径 4: 黑市顶部即使有"未同步"提示，也不再锁死整市场

- P3-1: `L2 脏 → 3 个商品卡都仍显示出售` ✅
- **P3-4: `L1+L2 同时存在 → 未锁商品的 onClick 不再被 L2 拦截`** ✅
- P3-2: `按钮文本永远不会出现⏳同步中` ✅

---

## 6. 残余风险声明（§7 明确要求）

### 6.1 本卡接受的残余风险

本卡接受的核心残余风险是：**未同步类卖出窗口重新暴露**。

当某个黑市可卖商品未被锁定、但客户端发生了本地先变化（快照尚未同步到服务端）时，卖出操作可能基于旧的背包快照执行。

### 6.2 具体暴露窗口

| 风险面 | 场景 | 暴露条件 |
|--------|------|----------|
| 仓库存取后卖 | 用户先存/取仓库，在 `game_saved` 前立即卖出 | `dirtyWarehouse=true` 时不再拦截 |
| 本地消耗后卖 | 用户使用令牌盒/消耗品，在 `game_saved` 前立即卖出 | `dirtyConsume=true` 时不再拦截 |
| SaveSession 活跃期间卖 | 存档流程进行中时卖出 | `SaveSession.IsDirty()=true` 时不再拦截 |
| 跨系统消耗后卖 | 炼丹/打造/附灵消耗后在 `game_saved` 前卖出 | 同上 |

### 6.3 缓解措施

- L1（`locked_item`）仍然完整有效 — 最近交易的商品受保护锁保护
- 服务端 `SellGuard` 完整拒绝全部高风险商品（79 类全部 blocked）
- 顶部"未同步"提示文字仍保留，给用户视觉提醒
- 后续如需补回 L2 防线，可单独立项，不与本卡混做

---

## 7. Runner 输出（§8）

### system 组（包含核心黑市测试）

```
[SUMMARY] total=23 executed=18 passed=18 failed=0 skipped=5
```

关键测试套件：
- `bm_fix01_card_sell_split` — 18/18 passed ✅
- `pre_c5a1_three_lines` — 27/27 passed ✅
- `bm_s4e_sell_block_consistency` — 21/21 passed ✅
- `bm_s4c_sell_block_model` — 20/20 passed ✅
- `bm_s4c1_confirm_dialog_buttons` — 10/10 passed ✅
- `bm_s4a_trade_lock` — 37/37 passed ✅
- `bm_s4ar_force_new_stack` — 18/18 passed ✅
- `bm_s4b_unlock_loop_and_ban` — 8/8 passed ✅
- `bm_s3_sell_guard` — 20/20 passed ✅
- `bm_s3_handle_sell_integration` — 10/10 passed ✅
- `bm_s4d_syncstate_after_save` — 18/18 passed ✅
- `bm_s4d_recycle_day_rollover` — 20/20 passed ✅
- `bm_s4e_recycle_tick_flow` — 38/38 passed ✅
- `bm_warehouse_consistency` — 19/19 passed ✅
- `bm_warehouse_consistency_01a` — 13/13 passed ✅
- `bm_s2_unified_sync_gate` — 18/18 passed ✅
- `prison_tower` — 450/450 passed ✅
- `recycle_system` — 115/115 passed ✅

### 其他组

```
smoke:      total=7, skipped=3, intentional_fail=2, passed=2 ✅
save:       total=6, passed=6, failed=0 ✅
config:     total=1, passed=1, failed=0 ✅
infra:      total=1, passed=1, failed=0 ✅
network:    total=1, passed=1, failed=0 ✅
combat:     total=5, skipped=5 (engine_required) ✅
regression: total=4, skipped=4 (engine_required) ✅
```

---

## 8. 验收对照（§9）

| 验收条件 | 状态 | 证据 |
|----------|------|------|
| 未锁商品恢复可卖 | ✅ 通过 | P2-2 onClick 放行、P2-3 confirm 放行 |
| 有锁商品仍然不可卖 | ✅ 通过 | P1-1 canSell=false、P4-3 L1 拦截 |
| 不再出现整市场被 global_unsync 锁死 | ✅ 通过 | P3-1 三商品均出售、P3-4 未锁 onClick 放行 |

---

## 9. 构建信息

- 构建版本: 1.0.916
- 入口: `client_main.lua` + `server_main.lua`
- manifest 验证: ✅ 双入口正确

---

## 10. Commit

- SHA: `e515c77`
- Message: `hotfix(BM-HOTFIX-SELL-01): 移除 onClick/confirm 的 global_unsync(L2) 拦截，恢复未锁商品卖出`
