function Start()
    local ok, err = pcall(function()
        local img = Image()
        local W, H = 256, 64
        img:SetSize(W, H, 4)

        -- ═══ 可调参数 ═══
        local solidPercent = 0.4   -- 实色占比（0.0~1.0）
        local curve = 2.0          -- 渐变曲线（1.0=线性, 1.5=柔和, 2.0=非常柔和, 0.5=锐利）
        -- ═════════════════

        -- UI 底色（匹配 panelBg: {25, 28, 38}）
        local r, g, b = 25/255, 28/255, 38/255
        local solidEnd = W * solidPercent
        local fadeLen = W - solidEnd

        for y = 0, H - 1 do
            for x = 0, W - 1 do
                local alpha
                if x <= solidEnd then
                    alpha = 1.0
                else
                    local t = (x - solidEnd) / fadeLen  -- 0→1
                    alpha = 1.0 - t ^ curve             -- curve越大，暗色保持越久
                end
                img:SetPixel(x, y, Color(r, g, b, alpha))
            end
        end

        assert(img:SavePNG("/workspace/assets/image/gradient_left_black.png"), "SavePNG failed")
        print("[procedural] wrote gradient_left_black.png (256x64) — left solid, mid-to-right fade")
    end)
    if not ok then log:Write(LOG_ERROR, "[gen_gradient] " .. tostring(err)) end
    engine:Exit()
end
