#!/usr/bin/env python3
"""
通过 lupa (Python Lua 绑定) 执行 run_all.lua
用于在没有独立 lua 解释器的环境中运行测试

用法:
    python3 scripts/tests/_run_via_lupa.py           # 运行所有测试
    python3 scripts/tests/_run_via_lupa.py save      # 只运行 save 组
    python3 scripts/tests/_run_via_lupa.py smoke     # 只运行 smoke 组
"""

import sys
import os

# 切换到项目根目录
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))

from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)

# 设置 package.path
lua.execute('package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")')

# 设置 arg 表（模拟命令行参数）
group_filter = sys.argv[1] if len(sys.argv) > 1 else None
if group_filter:
    lua.execute(f'arg = {{[1] = "{group_filter}"}}')
else:
    lua.execute('arg = {}')

# 替换 os.exit 为抛异常，以便 Python 可以获取退出码
lua.execute('''
local _real_exit = os.exit
local _exit_code = 0
os.exit = function(code)
    _exit_code = code or 0
    error("__EXIT__:" .. tostring(code))
end
function _get_exit_code()
    return _exit_code
end
''')

# 执行 run_all.lua
try:
    lua.execute('dofile("scripts/tests/run_all.lua")')
    sys.exit(0)
except Exception as e:
    err_msg = str(e)
    if "__EXIT__:" in err_msg:
        # 提取退出码
        code_str = err_msg.split("__EXIT__:")[1].split('"')[0].strip()
        try:
            exit_code = int(code_str)
        except ValueError:
            exit_code = 1
        sys.exit(exit_code)
    else:
        print(f"\nFATAL: {e}", file=sys.stderr)
        sys.exit(2)
