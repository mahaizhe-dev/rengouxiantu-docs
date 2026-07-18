# 图片资源管理器

项目图片资源的只读审计工具。首版提供：

- PNG 缩略图、尺寸、体积、UUID 和 SHA-256。
- 运行时直接引用、动态家族引用、开发引用和未发现引用分类。
- 内容完全相同的重复图片分组。
- 时间戳、版本标记、非 snake_case 等命名问题。
- 缺失图片引用和同名路径建议。
- Maker 本地生成来源、提示词和生成时间。
- T1-T10、仙1 制式装备归类，包含阶位/槽位筛选、接入状态和仙1沿用关系。
- 怪物头像归类，支持按章节、怪物类型查看同图复用配置。
- 特殊装备图标归类，支持按配置表和装备槽位筛选。

## 启动

直接双击：

```text
start-image-manager.cmd
```

启动器会在最小化窗口中运行服务，并打开管理器页面。

也可以在项目根目录运行：

```powershell
node devtools\image-manager\server.mjs
```

然后访问：

```text
http://127.0.0.1:4317
```

如端口被占用：

```powershell
$env:IMAGE_MANAGER_PORT=4318
node devtools\image-manager\server.mjs
```

## 命令行扫描

```powershell
node devtools\image-manager\scan-cli.mjs
```

输出完整 JSON：

```powershell
node devtools\image-manager\scan-cli.mjs --json
```

工具不会修改、移动或删除项目图片。
