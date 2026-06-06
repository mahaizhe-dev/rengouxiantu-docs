---@diagnostic disable
-- ============================================================================
-- AudioSystem.lua — 音频系统（BGM + 掉落音效）
-- 三档音量：大(high) / 小(low) / 关(off)
-- 五类掉落音优先级 A>B>C>D>E，高优先级可打断低优先级
-- 持久化：本地文件（不走云存档）
-- ============================================================================

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local cjson = require("cjson")
local GameConfig = require("config.GameConfig")

local AudioSystem = {}

-- ── 三档音量定义 ──
local VOLUME_LEVELS = { "high", "low", "off" }  -- 循环顺序：大→小→关→大

-- 增益值映射
local BGM_GAIN = { high = 0.35, low = 0.15, off = 0 }
local DROP_GAIN = { high = 0.65, low = 0.30, off = 0 }

-- 显示名映射
local LEVEL_DISPLAY = { high = "大", low = "小", off = "关" }

-- ── 内部状态 ──
local bgmScene_ = nil       ---@type Scene|nil
local bgmSource_ = nil      ---@type SoundSource|nil
local bgmLevel_ = "high"    -- "high"|"low"|"off"
local dropLevel_ = "high"   -- "high"|"low"|"off"

local dropScene_ = nil      ---@type Scene|nil
local dropSource_ = nil     ---@type SoundSource|nil
local currentDropPriority_ = 0  -- 当前正在播放的掉落音优先级

-- ── 本地文件持久化 ──
local SETTINGS_FILE = "audio_settings.json"

--- 从本地文件加载设置（安全：任何异常静默跳过）
local function LoadLocalSettings()
    local ok, err = pcall(function()
        if not fileSystem or not fileSystem:FileExists(SETTINGS_FILE) then return end
        local file = File(SETTINGS_FILE, FILE_READ)
        if not file or not file:IsOpen() then return end
        local raw = file:ReadString()
        file:Close()
        local decOk, data = pcall(cjson.decode, raw)
        if decOk and type(data) == "table" then
            if data.bgmLevel and BGM_GAIN[data.bgmLevel] ~= nil then
                bgmLevel_ = data.bgmLevel
            end
            if data.dropLevel and DROP_GAIN[data.dropLevel] ~= nil then
                dropLevel_ = data.dropLevel
            end
        end
    end)
    if not ok then
        print("[AudioSystem] WARNING: LoadLocalSettings failed: " .. tostring(err))
    end
end

--- 保存设置到本地文件（安全：写入失败静默跳过）
local function SaveLocalSettings()
    local ok, err = pcall(function()
        local file = File(SETTINGS_FILE, FILE_WRITE)
        if not file or not file:IsOpen() then return end
        file:WriteString(cjson.encode({
            bgmLevel = bgmLevel_,
            dropLevel = dropLevel_,
        }))
        file:Close()
    end)
    if not ok then
        print("[AudioSystem] WARNING: SaveLocalSettings failed: " .. tostring(err))
    end
end

-- ── 章节 BGM 映射 ──
local CHAPTER_BGM = {
    [1]   = "audio/music_1772863945987.ogg",    -- 两界村（登录共用）
    [2]   = "audio/music_1772864079904.ogg",    -- 乌家堡
    [3]   = "audio/music_1773407979739.ogg",    -- 万里黄沙
    [4]   = "audio/music_1775307731590.ogg",    -- 八卦海
    [5]   = "audio/music_1780401351910.ogg",    -- 太虚之殇
    [101] = "audio/music_1780401197569.ogg",    -- 中洲仙城
}

-- ============================================================================
-- 五类掉落音定义（优先级 A=5 > B=4 > C=3 > D=2 > E=1）
-- ============================================================================

-- 优先级常量
local PRIORITY_A = 5  -- 神器碎片
local PRIORITY_B = 4  -- 灵器及以上装备
local PRIORITY_C = 3  -- 黑市-消耗品
local PRIORITY_D = 2  -- 角色进阶丹药、上品灵韵果、黑市-草药
local PRIORITY_E = 1  -- 灵韵果、宠物进阶丹药、黑市-书籍、特殊装备

-- 音频文件路径
local AUDIO_A = "audio/神圣石.ogg"       -- A类：神器碎片
local AUDIO_B = "audio/金色传说.ogg"      -- B类：灵器及以上装备
local AUDIO_C = "audio/ggS.ogg"          -- C类：黑市-消耗品
local AUDIO_D = "audio/财源滚滚.ogg"      -- D类：角色进阶丹药/上品灵韵果/黑市-草药
local AUDIO_E = "audio/这张卡不错.ogg"     -- E类：灵韵果/宠物进阶丹药/黑市-书籍/特殊装备

-- ── 消耗品分类集合 ──

-- D类：角色进阶丹药
local CHAR_ADVANCE_PILLS = {
    qi_pill = true,
    zhuji_pill = true,
    jindan_sand = true,
    jiuzhuan_jindan = true,
    dujie_dan = true,
    xian_dan = true,
}

-- D类：上品灵韵果
local SUPERIOR_FRUIT = {
    lingyun_fruit_superior = true,
}

-- E类：普通灵韵果
local NORMAL_FRUIT = {
    lingyun_fruit = true,
}

-- E类：宠物进阶丹药
local PET_ADVANCE_PILLS = {
    spirit_pill = true,
    spirit_pill_2 = true,
    spirit_pill_3 = true,
    spirit_pill_4 = true,
    spirit_pill_5 = true,
    spirit_pill_6 = true,
    spirit_pill_7 = true,
}

-- 黑市书籍 category 集合
local BOOK_CATEGORIES = {
    skill_book_mid     = true,
    skill_book_high    = true,
    skill_book_special = true,
}

-- 黑市消耗品 category 集合（C类）
local MARKET_CONSUMABLE_CATEGORIES = {
    consumable_mat = true,
    lingyu         = true,
}

-- "灵器"及以上品质阈值 (QUALITY_ORDER >= 6)
local QUALITY_THRESHOLD_LINGQI = 6

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化音频系统（在 Scene 创建后调用）
function AudioSystem.Init()
    -- 先从本地加载设置
    LoadLocalSettings()

    -- BGM Scene + SoundSource
    if not bgmScene_ then
        bgmScene_ = Scene()
        local node = bgmScene_:CreateChild("BGM")
        bgmSource_ = node:CreateComponent("SoundSource")
        bgmSource_:SetSoundType("Music")
        bgmSource_.gain = BGM_GAIN[bgmLevel_]
    end

    -- 掉落音 Scene + SoundSource
    if not dropScene_ then
        dropScene_ = Scene()
        local node = dropScene_:CreateChild("DropCue")
        dropSource_ = node:CreateComponent("SoundSource")
        dropSource_:SetSoundType("Effect")
        dropSource_.gain = DROP_GAIN[dropLevel_]
    end

    print("[AudioSystem] Initialized (bgm=" .. bgmLevel_ .. " drop=" .. dropLevel_ .. ")")
end

-- ============================================================================
-- 音量档位循环
-- ============================================================================

--- 获取下一档音量（大→小→关→大）
---@param current string
---@return string
local function NextLevel(current)
    for i, lv in ipairs(VOLUME_LEVELS) do
        if lv == current then
            return VOLUME_LEVELS[(i % #VOLUME_LEVELS) + 1]
        end
    end
    return "high"
end

-- ============================================================================
-- BGM 控制
-- ============================================================================

--- 播放指定章节的背景音乐（安全：异常静默失败）
---@param chapterId number
function AudioSystem.PlayBGM(chapterId)
    local path = CHAPTER_BGM[chapterId]
    if not path then return end

    if not bgmSource_ then
        pcall(AudioSystem.Init)
    end
    if not bgmSource_ then return end

    -- 关闭状态不播放
    if bgmLevel_ == "off" then return end

    local sound = cache:GetResource("Sound", path)
    if not sound then return end

    sound.looped = true
    pcall(function()
        bgmSource_.gain = BGM_GAIN[bgmLevel_]
        bgmSource_:Play(sound)
    end)
end

--- 停止背景音乐
function AudioSystem.StopBGM()
    if bgmSource_ then
        pcall(function() bgmSource_:Stop() end)
    end
end

--- 设置 BGM 音量档位
---@param level string "high"|"low"|"off"
function AudioSystem.SetBGMLevel(level)
    if not BGM_GAIN[level] then return end
    bgmLevel_ = level
    if bgmSource_ then
        pcall(function() bgmSource_.gain = BGM_GAIN[level] end)
    end
    if level == "off" then
        AudioSystem.StopBGM()
    else
        -- 非关闭时，如果当前没在播放则恢复播放
        local isPlaying = false
        if bgmSource_ then
            local checkOk, playing = pcall(function() return bgmSource_:IsPlaying() end)
            isPlaying = checkOk and playing
        end
        if bgmSource_ and not isPlaying then
            AudioSystem.PlayBGM(GameState.currentChapter or 1)
        end
    end
    SaveLocalSettings()
end

--- 循环切换 BGM 档位（大→小→关→大）
---@return string newLevel
function AudioSystem.CycleBGMLevel()
    local newLevel = NextLevel(bgmLevel_)
    AudioSystem.SetBGMLevel(newLevel)
    return newLevel
end

--- 获取 BGM 音量档位
---@return string "high"|"low"|"off"
function AudioSystem.GetBGMLevel()
    return bgmLevel_
end

--- 获取档位显示名
---@param level string
---@return string
function AudioSystem.GetLevelDisplay(level)
    return LEVEL_DISPLAY[level] or "?"
end

-- 兼容旧接口（main.lua 的全局委托）
function AudioSystem.SetBGMEnabled(enabled)
    AudioSystem.SetBGMLevel(enabled and "high" or "off")
end

function AudioSystem.IsBGMEnabled()
    return bgmLevel_ ~= "off"
end

-- ============================================================================
-- 掉落音控制（优先级打断逻辑）
-- ============================================================================

--- 播放掉落音（优先级模式：高优先级可打断低优先级）
--- 安全保证：任何异常静默失败，绝不崩溃
---@param audioPath string 音频文件路径
---@param priority number 优先级数值（越大越高）
local function PlayDropCueInternal(audioPath, priority)
    if dropLevel_ == "off" then return end

    if not dropSource_ then
        pcall(AudioSystem.Init)
    end
    -- Init 后仍然为 nil → 放弃播放
    if not dropSource_ then return end

    -- 优先级判断：当前正在播放且当前优先级 >= 新优先级 → 不打断
    local checkOk, playing = pcall(function() return dropSource_:IsPlaying() end)
    if checkOk and playing and currentDropPriority_ >= priority then
        return
    end

    -- 停止当前并播放新音效
    pcall(function() dropSource_:Stop() end)

    local sound = cache:GetResource("Sound", audioPath)
    if not sound then return end

    sound.looped = false
    local playOk = pcall(function()
        dropSource_.gain = DROP_GAIN[dropLevel_]
        dropSource_:Play(sound)
    end)
    if playOk then
        currentDropPriority_ = priority
    end
end

--- 设置掉落音音量档位
---@param level string "high"|"low"|"off"
function AudioSystem.SetDropLevel(level)
    if not DROP_GAIN[level] then return end
    dropLevel_ = level
    if dropSource_ then
        pcall(function() dropSource_.gain = DROP_GAIN[level] end)
    end
    if level == "off" and dropSource_ then
        pcall(function() dropSource_:Stop() end)
        currentDropPriority_ = 0
    end
    SaveLocalSettings()
end

--- 循环切换掉落音档位（大→小→关→大）
---@return string newLevel
function AudioSystem.CycleDropLevel()
    local newLevel = NextLevel(dropLevel_)
    AudioSystem.SetDropLevel(newLevel)
    return newLevel
end

--- 获取掉落音音量档位
---@return string "high"|"low"|"off"
function AudioSystem.GetDropLevel()
    return dropLevel_
end

-- 兼容旧接口
function AudioSystem.SetDropVoiceEnabled(enabled)
    AudioSystem.SetDropLevel(enabled and "high" or "off")
end

function AudioSystem.IsDropVoiceEnabled()
    return dropLevel_ ~= "off"
end

-- ============================================================================
-- 存档集成（已废弃，保留兼容空方法）
-- ============================================================================

--- 旧接口：应用存档中的音频设置（不再使用，设置从本地文件加载）
---@param settings table|nil
function AudioSystem.ApplySettings(settings)
    -- 不再从云存档加载音频设置，改用本地文件
end

--- 旧接口：获取音频设置（不再序列化到云存档）
---@return table
function AudioSystem.GetSettings()
    return {
        musicEnabled = bgmLevel_ ~= "off",
        dropVoiceEnabled = dropLevel_ ~= "off",
    }
end

-- ============================================================================
-- 掉落音判定辅助（供 LootSystem / pickup 调用）
-- ============================================================================

--- 判断拾取的装备是否应触发掉落音，如果是则播放
--- 判定顺序按优先级从高到低，命中最高优先级即播放
---@param item table 装备 item 表（含 quality / isSpecial / equipId 等字段）
function AudioSystem.CheckAndPlayForItem(item)
    if not item then return end

    -- B类：灵器及以上装备（quality >= cyan）
    local qualityOrder = item.quality and GameConfig.QUALITY_ORDER[item.quality] or 0
    if qualityOrder >= QUALITY_THRESHOLD_LINGQI then
        PlayDropCueInternal(AUDIO_B, PRIORITY_B)
        return
    end

    -- B类：黑市特殊装备（帝尊戒指系列）
    local ok, BMConfig = pcall(require, "config.BlackMerchantConfig")
    if ok and BMConfig and BMConfig.ITEMS then
        for _, bmItem in pairs(BMConfig.ITEMS) do
            if type(bmItem) == "table" and bmItem.equipId and bmItem.equipId == item.equipId then
                local cat = bmItem.category
                if cat == "special_equip" then
                    PlayDropCueInternal(AUDIO_B, PRIORITY_B)
                    return
                elseif MARKET_CONSUMABLE_CATEGORIES[cat] then
                    -- C类：黑市消耗品
                    PlayDropCueInternal(AUDIO_C, PRIORITY_C)
                    return
                elseif cat == "herb" then
                    -- D类：黑市草药
                    PlayDropCueInternal(AUDIO_D, PRIORITY_D)
                    return
                elseif BOOK_CATEGORIES[cat] then
                    -- E类：黑市书籍
                    PlayDropCueInternal(AUDIO_E, PRIORITY_E)
                    return
                end
            end
        end
    end

    -- E类：特殊装备（掉落的法宝也算，挑战获得的法宝不经过此路径）
    if item.isSpecial then
        PlayDropCueInternal(AUDIO_E, PRIORITY_E)
        return
    end
end

--- B类：美酒获得（由 WineSystem.ObtainWine 调用）
function AudioSystem.PlayWineCue()
    PlayDropCueInternal(AUDIO_B, PRIORITY_B)
end

--- 命格掉落音效（紫E/橙D/青B）
--- 传入命格品质字符串，播放对应类别音效
---@param quality string "purple"|"orange"|"cyan"
function AudioSystem.PlayMinggeCue(quality)
    if quality == "cyan" then
        PlayDropCueInternal(AUDIO_B, PRIORITY_B)
    elseif quality == "orange" then
        PlayDropCueInternal(AUDIO_D, PRIORITY_D)
    elseif quality == "purple" then
        PlayDropCueInternal(AUDIO_E, PRIORITY_E)
    end
end

--- 判断消耗品是否应触发掉落音
--- 判定顺序按优先级从高到低，命中最高优先级即播放
---@param consumableId string
function AudioSystem.CheckAndPlayForConsumable(consumableId)
    if not consumableId then return end

    -- A类：神器碎片（ID 含 _fragment_）
    if string.find(consumableId, "_fragment_") then
        PlayDropCueInternal(AUDIO_A, PRIORITY_A)
        return
    end

    -- D类：角色进阶丹药
    if CHAR_ADVANCE_PILLS[consumableId] then
        PlayDropCueInternal(AUDIO_D, PRIORITY_D)
        return
    end

    -- D类：上品灵韵果
    if SUPERIOR_FRUIT[consumableId] then
        PlayDropCueInternal(AUDIO_D, PRIORITY_D)
        return
    end

    -- E类：普通灵韵果
    if NORMAL_FRUIT[consumableId] then
        PlayDropCueInternal(AUDIO_E, PRIORITY_E)
        return
    end

    -- E类：宠物进阶丹药
    if PET_ADVANCE_PILLS[consumableId] then
        PlayDropCueInternal(AUDIO_E, PRIORITY_E)
        return
    end

    -- 黑市消耗品判定
    local ok, BMConfig = pcall(require, "config.BlackMerchantConfig")
    if ok and BMConfig and BMConfig.ITEMS then
        local bmItem = BMConfig.ITEMS[consumableId]
        if type(bmItem) == "table" then
            local cat = bmItem.category
            if cat == "herb" then
                -- D类：黑市草药
                PlayDropCueInternal(AUDIO_D, PRIORITY_D)
            elseif BOOK_CATEGORIES[cat] then
                -- E类：黑市书籍
                PlayDropCueInternal(AUDIO_E, PRIORITY_E)
            elseif MARKET_CONSUMABLE_CATEGORIES[cat] then
                -- C类：黑市消耗品（consumable_mat / lingyu）
                PlayDropCueInternal(AUDIO_C, PRIORITY_C)
            end
            return
        end
    end
end

return AudioSystem
