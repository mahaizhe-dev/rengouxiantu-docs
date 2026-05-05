-- ============================================================================
-- wild_inner.lua - 内域荒漠（黄天寨入口走廊，③→①/②→① 通道）
-- ③→① 纵向 (x≈56~73, y=50~53)，②→① 横向 (x=50~53, y≈56~73)
-- 沙暴妖帅 ×5 (elite Lv63, 元婴中)
-- ============================================================================

local wild_inner = {}

wild_inner.npcs = {}

-- 沙暴妖帅：扼守通往黄天寨的最后通道，最强精英
wild_inner.spawns = {
    -- ③→① 纵向通道（北侧入口→东侧边缘）
    { type = "sand_elite_inner", x = 58, y = 51 },
    { type = "sand_elite_inner", x = 67, y = 52 },
    { type = "sand_elite_inner", x = 73, y = 51 },
    -- ②→① 横向通道（西侧入口→南段边缘）
    { type = "sand_elite_inner", x = 51, y = 59 },
    { type = "sand_elite_inner", x = 52, y = 68 },
}

wild_inner.decorations = {}

return wild_inner
