function Start()
    local ok, err = pcall(function()
        -- 尝试获取 serverCloud 接口
        if not serverCloud then
            print("[query] serverCloud not available in headless mode")
            engine:Exit()
            return
        end

        print("[query] serverCloud available, querying xianshi_rank top 5...")
        serverCloud:GetRankList("xianshi_rank", 1, 5, {
            ok = function(rankList)
                print("[query] Got " .. #rankList .. " entries:")
                for i, item in ipairs(rankList) do
                    local score = item.iscore and item.iscore.xianshi_rank or "?"
                    print(string.format("  #%d userId=%s xianshi=%s", i, tostring(item.userId), tostring(score)))
                end
                engine:Exit()
            end,
            error = function(code, reason)
                print("[query] GetRankList FAILED: " .. tostring(code) .. " " .. tostring(reason))
                engine:Exit()
            end,
        })
    end)
    if not ok then
        print("[query] ERROR: " .. tostring(err))
        engine:Exit()
    end
end
