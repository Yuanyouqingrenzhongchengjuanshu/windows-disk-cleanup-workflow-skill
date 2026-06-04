# Windows 硬盘清理工作流 Skill

中文 | [English](./README.md)

这是一个用于 Codex 的 Skill，用来通过“持久化状态机工作流”安全清理用户指定的 Windows 磁盘。

## 概述

这个 Skill 用于帮助 Codex 检查和清理 Windows 硬盘空间。它不会默认只处理 `C:`，用户可以指定 `C:`、`D:`、`E:` 或其他有效的 Windows 文件系统磁盘。

整个工作流会把进度持久化到本地文件中。这样下一次继续执行时，Codex 会先读取本地状态文件，恢复当前节点和上次结果，减少依赖聊天上下文导致的遗漏和幻觉。

## 核心功能

- 支持指定目标磁盘，例如 `C:`、`D:`、`E:`
- 使用 `workflow_state.json` 持久化当前状态
- 按节点执行状态机流程
- 使用 JSON 快照保存扫描结果
- 使用 Markdown 保存节点日志和完整流程日志
- 删除、移动、清空回收站、组件缓存清理前必须经过确认节点
- 支持中断后恢复
- 保守处理个人文件、源代码、下载目录、虚拟环境和 Docker volume

## Skill 目录结构

```text
windows-disk-cleanup-workflow-skill/
├─ SKILL.md
├─ README.md
├─ README.zh-CN.md
├─ .gitignore
├─ references/
│  └─ workflow.md
└─ scripts/
   └─ bootstrap.ps1
```

## 安装到 Codex 本地 Skill 目录

把整个目录复制到 Codex skills 目录。

```powershell
mkdir $env:USERPROFILE\.codex\skills -Force
Copy-Item .\windows-disk-cleanup-workflow-skill $env:USERPROFILE\.codex\skills\windows-disk-cleanup-workflow -Recurse -Force
```

## 在 Codex 中启动

调用 Skill，并明确指定目标磁盘。

```text
$windows-disk-cleanup-workflow
请启动 Windows 硬盘清理持久化状态机工作流，目标磁盘是 D:。
```

也可以使用英文：

```text
$windows-disk-cleanup-workflow
Start the persistent Windows disk cleanup state-machine workflow. The target drive is D:.
```

## 手动初始化工作区

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -TargetDrive D:
```

初始化脚本会在桌面创建工作区：

```text
%USERPROFILE%\Desktop\windows_disk_cleanup_workflow
```

## 持久化工作流文件

```text
windows_disk_cleanup_workflow/
├─ README_WORKFLOW.md
├─ workflow_state.json
├─ workflow_log.md
├─ node_logs/
├─ snapshots/
└─ commands/
```

各文件作用如下：

| 路径 | 作用 |
|---|---|
| `README_WORKFLOW.md` | 记录工作流规则和节点顺序 |
| `workflow_state.json` | 记录当前节点、目标磁盘、确认状态和下一步动作 |
| `workflow_log.md` | 记录完整流程时间线 |
| `node_logs/` | 每个节点一份可读日志 |
| `snapshots/` | 用 JSON 保存扫描得到的事实数据 |
| `commands/` | 记录建议命令、已执行命令、已跳过命令 |

## 安全策略

这个 Skill 默认非常保守：

1. 先扫描，再清理。
2. 先预览，再执行。
3. 风险操作必须输入指定确认文本。
4. 不自动删除个人文件。
5. 不修改注册表。
6. 不直接删除 Windows 核心目录或软件安装目录。
7. 不自动清理 Docker volume。
8. 命令失败必须记录错误，不能写成成功。

## 目标磁盘机制

用户指定的磁盘会被写入 `workflow_state.json`：

```json
{
  "target_drive": "D:",
  "target_root": "D:\\",
  "system_drive": "C:"
}
```

如果后续运行时指定了不同磁盘，Skill 必须停止，并询问是创建新流程还是重置当前状态。这样可以避免把 D 盘的扫描结果误用于 E 盘。

## 典型流程

```text
N0 恢复或初始化
N1 初始化与安全确认
N2 磁盘空间诊断
N3 目标磁盘目录占用分析
N4 目标磁盘大文件扫描
N5 生成清理候选清单
N6 低风险临时文件预览
N7 等待人工确认
N8 执行已确认清理
...
N24 生成最终报告
```

完整状态机见 [`references/workflow.md`](./references/workflow.md)。

## GitHub 双语说明建议

`README.md` 作为英文首页，`README.zh-CN.md` 作为中文首页。GitHub 的 Markdown 不支持自定义 JavaScript，所以语言切换采用顶部链接方式实现，这是最稳定、最兼容的方案。
