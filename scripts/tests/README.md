# 人狗仙途 — 测试框架

## 环境要求

- Python 3.6+
- lupa (`pip install lupa`)

```bash
pip install -r scripts/tests/requirements.txt
```

## 测试命令

### 默认门禁（仅 blocking 测试）

```bash
python3 scripts/tests/_run_via_lupa.py
```

### 全量测试

```bash
python3 scripts/tests/_run_via_lupa.py --all
```

### 按 gate 类型过滤

```bash
python3 scripts/tests/_run_via_lupa.py --gate=blocking
python3 scripts/tests/_run_via_lupa.py --gate=non_blocking
python3 scripts/tests/_run_via_lupa.py --gate=known_red
```

### 按 group 过滤

```bash
python3 scripts/tests/_run_via_lupa.py save
python3 scripts/tests/_run_via_lupa.py combat
python3 scripts/tests/_run_via_lupa.py smoke
python3 scripts/tests/_run_via_lupa.py system
python3 scripts/tests/_run_via_lupa.py regression
```

## 退出码

| 码 | 含义 |
|----|------|
| 0  | 全部通过（且有实际执行） |
| 1  | 有测试失败 |
| 2  | 无有效执行（全部 skip 或空集合） |
| 3  | 环境检查失败（Python/lupa 不可用） |

## 门禁分类 (gate)

| gate | 含义 | 默认门禁是否运行 |
|------|------|------------------|
| `blocking` | 阻断门禁，必须全绿 | 是 |
| `non_blocking` | 非阻断，可显式执行 | 否 |
| `known_red` | 已知问题，隔离跟踪 | 否 |
