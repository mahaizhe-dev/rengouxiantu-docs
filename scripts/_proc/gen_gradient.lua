function Start()
    local ok, err = pcall(function()
        local img = Image()
        local W, H = 256, 64
        img:SetSize(W, H, 4)

        local solidEnd = W / 3        -- 左1/3纯黑
        local fadeLen = W - solidEnd  -- 右2/3全部为渐变区

        for y = 0, H - 1 do
            for x = 0, W - 1 do
                local alpha
                if x <= solidEnd then
                    alpha = 1.0  -- 左1/3：纯黑
                else
                    alpha = 1.0 - ((x - solidEnd) / fadeLen)  -- 右2/3：线性渐变到透明
                end
                img:SetPixel(x, y, Color(0, 0, 0, alpha))
            end
        end

        assert(img:SavePNG("/workspace/assets/image/gradient_left_black.png"), "SavePNG failed")
        print("[procedural] wrote gradient_left_black.png (256x64) — left solid, mid-to-right fade")
    end)
    if not ok then log:Write(LOG_ERROR, "[gen_gradient] " .. tostring(err)) end
    engine:Exit()
end
