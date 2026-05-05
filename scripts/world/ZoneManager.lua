-- ============================================================================
-- ZoneManager.lua - 区域切换管理（从 main.lua 提取）
-- ============================================================================

local GameState = require("core.GameState")
local ChapterConfig = require("config.ChapterConfig")

local ZoneManager = {}

-- 区域信息表（从各章节 ZoneData.ZONE_INFO 自动合并）
ZoneManager.ZONE_INFO = {}
for _, chapter in pairs(ChapterConfig.CHAPTERS) do
    local ok, zd = pcall(require, chapter.zoneDataModule)
    if ok and zd and zd.ZONE_INFO then
        for zoneId, info in pairs(zd.ZONE_INFO) do
            ZoneManager.ZONE_INFO[zoneId] = info
        end
    end
end

-- 上次显示的区域名
local lastZoneNotice_ = ""

--- 检查并处理区域切换
---@param gameMap table
---@param player table
---@param uiRoot table|nil UI根节点（用于显示提示）
function ZoneManager.CheckZoneChange(gameMap, player, uiRoot)
    local zone = gameMap:GetZoneAt(player.x, player.y + player.collisionOffsetY)
    if zone ~= GameState.currentZone then
        local prevZone = GameState.currentZone
        GameState.currentZone = zone
        ZoneManager.OnZoneChanged(prevZone, zone, uiRoot)
    end
end

--- 区域切换回调
---@param fromZone string
---@param toZone string
---@param uiRoot table|nil
function ZoneManager.OnZoneChanged(fromZone, toZone, uiRoot)
    local T = require("config.UITheme")
    local info = ZoneManager.ZONE_INFO[toZone]
    local name = info and info.name or toZone
    if name ~= lastZoneNotice_ then
        lastZoneNotice_ = name
        print("[Zone] Entered: " .. name)
        -- 显示区域提示
        if uiRoot then
            local notice = uiRoot:FindById("zoneNotice")
            if notice then
                local nameLabel = notice:FindById("zoneNoticeName")
                if nameLabel then
                    nameLabel:SetText("— " .. name .. " —")
                end
                local levelLabel = notice:FindById("zoneNoticeLevel")
                if levelLabel then
                    if info and info.levelRange then
                        levelLabel:SetText("Lv." .. info.levelRange[1] .. " ~ Lv." .. info.levelRange[2])
                        levelLabel:SetVisible(true)
                    else
                        levelLabel:SetText("安全区域")
                        levelLabel:SetVisible(true)
                    end
                end
                notice:Animate({
                    keyframes = {
                        [0]   = { opacity = 1 },
                        [0.7] = { opacity = 1 },
                        [1]   = { opacity = 0 },
                    },
                    duration = 3.0,
                })
            end
        end
    end
end

--- 重置（登出时调用）
function ZoneManager.Reset()
    lastZoneNotice_ = ""
end

return ZoneManager
