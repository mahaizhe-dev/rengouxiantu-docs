#!/usr/bin/env python3
"""
通过 lupa (Python Lua 绑定) 执行 run_all.lua
用于在没有独立 lua 解释器的环境中运行测试

P0-1:  初始版本
P0-1A: 固化运行环境检查，增加明确错误提示

用法:
    python3 scripts/tests/_run_via_lupa.py              # 默认门禁（仅 blocking）
    python3 scripts/tests/_run_via_lupa.py --all        # 运行所有测试
    python3 scripts/tests/_run_via_lupa.py --gate=blocking    # 按 gate 过滤
    python3 scripts/tests/_run_via_lupa.py save         # 只运行 save 组
    python3 scripts/tests/_run_via_lupa.py smoke        # 只运行 smoke 组
"""

import sys
import os

# ============================================================================
# P0-1A: 运行环境前置检查
# ============================================================================

def check_environment():
    """检查运行环境，失败时打印明确指导信息并退出"""
    errors = []

    # 检查 Python 版本（需要 3.6+）
    if sys.version_info < (3, 6):
        errors.append(
            f"ERROR: Python >= 3.6 required, current: {sys.version}\n"
            f"  Fix: Install Python 3.6+ or use pyenv"
        )

    # 检查 lupa 是否可导入
    try:
        import lupa
        from lupa import LuaRuntime
    except ImportError as e:
        errors.append(
            f"ERROR: lupa module not found ({e})\n"
            f"  Fix: pip install lupa\n"
            f"  See: scripts/tests/requirements.txt"
        )

    # 检查工作目录结构
    # _run_via_lupa.py 位于 scripts/tests/，项目根在两级以上
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.join(script_dir, '..', '..')
    project_root = os.path.normpath(project_root)

    run_all_path = os.path.join(project_root, 'scripts', 'tests', 'run_all.lua')
    if not os.path.isfile(run_all_path):
        errors.append(
            f"ERROR: scripts/tests/run_all.lua not found at {run_all_path}\n"
            f"  Fix: Run from project root, or check file exists"
        )

    if errors:
        print("=" * 60, file=sys.stderr)
        print("  ENVIRONMENT CHECK FAILED", file=sys.stderr)
        print("=" * 60, file=sys.stderr)
        for err in errors:
            print("", file=sys.stderr)
            print(err, file=sys.stderr)
        print("", file=sys.stderr)
        sys.exit(3)

    return project_root

# ============================================================================
# 主流程
# ============================================================================

project_root = check_environment()

# 切换到项目根目录
os.chdir(project_root)

from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)

# 设置 package.path
lua.execute('package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")')

# 设置 arg 表（模拟命令行参数）
raw_arg = sys.argv[1] if len(sys.argv) > 1 else None
if raw_arg:
    # 转义引号防注入
    safe_arg = raw_arg.replace('\\', '\\\\').replace('"', '\\"')
    lua.execute(f'arg = {{[1] = "{safe_arg}"}}')
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
