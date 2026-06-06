-- 运行命格配置完整性测试
function Start()
    local ok, err = pcall(function()
        local test = require("tests.test_mingge_config")
        local success = test.run()
        if success then
            print("[TEST] ALL PASSED")
        else
            print("[TEST] SOME TESTS FAILED")
        end
    end)
    if not ok then
        print("[TEST] ERROR: " .. tostring(err))
    end
    engine:Exit()
end
