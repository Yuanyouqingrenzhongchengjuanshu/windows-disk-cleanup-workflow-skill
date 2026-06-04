---
name: windows-disk-cleanup-workflow
description: Use this skill when the user wants Codex to safely clean a specific Windows drive through a persistent, resumable, state-machine workflow. Trigger for Windows disk cleanup, C/D/E drive cleanup, storage analysis, target-drive temp/cache cleanup, developer cache cleanup, recycle bin checks, large file inventory, and cleanup workflows that require checkpoints, confirmations, logs, and recovery across sessions. The workflow must accept a user-specified target drive and must not assume C: unless the user explicitly chooses it. Do not use for Linux/macOS cleanup or destructive wipe/reset tasks.
---

# Windows Disk Cleanup Persistent Workflow Skill

You are helping the user safely clean Windows disk space. Treat the task as a resumable state machine backed by files on disk, not as a one-shot chat task.

## Required drive-scope rule

The workflow is target-drive based.

1. The user may specify any existing Windows filesystem drive, such as `C:`, `D:`, `E:`.
2. Do not assume `C:` unless the user explicitly chooses `C:`.
3. Persist the selected drive in `workflow_state.json` as `target_drive` and `target_root`.
4. Every scan, preview, cleanup, duplicate check, and move recommendation must be scoped to `target_drive`, except global status checks that only read all drives for comparison.
5. If `target_drive` is missing from state, stop and ask the user to provide a drive letter.
6. If the selected drive does not exist, stop and ask for a valid drive letter.
7. Windows component cleanup is only valid for the system drive. If `target_drive` is not the system drive, skip Windows component cleanup nodes and record the skip reason.
8. Recycle bin cleanup must target the selected drive where the command supports it.

## Non-negotiable safety rules

1. Never delete, move, empty, prune, or reset anything before a preview node and an explicit confirmation node.
2. Never delete personal files automatically, including Desktop, Downloads, Documents, Pictures, Videos, source code, archives, installers, virtual environments, project folders, or user-created assets.
3. Never edit the registry.
4. Never delete Windows core folders or application installation folders directly.
5. Never use third-party cleaner tools.
6. Never use `DISM /ResetBase` unless the user separately asks for it after you explain that it prevents uninstalling superseded updates.
7. Never use Docker volume prune automatically.
8. If a command fails, record the failure. Do not claim success.
9. Do not rely on chat memory as the source of truth. Read the persisted state before every node.
10. If state files are missing, corrupted, or contradictory, stop and ask the user how to proceed.

## Required persisted workspace

Default workspace:

```powershell
$CleanupRoot = "$env:USERPROFILE\Desktop\windows_disk_cleanup_workflow"
```

Required structure:

```text
windows_disk_cleanup_workflow/
├─ README_WORKFLOW.md
├─ workflow_state.json
├─ workflow_log.md
├─ node_logs/
├─ snapshots/
└─ commands/
```

Use `scripts/bootstrap.ps1` from this skill when available to create the workspace and baseline files. Pass `-TargetDrive` when the user provides a drive.

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -TargetDrive D:
```

## Startup protocol

At the start of every task:

1. Locate this skill's reference document: `references/workflow.md`.
2. Determine whether the user provided a target drive in the current request.
3. Check whether `$CleanupRoot` exists.
4. If it does not exist, initialize the workflow at `N1_初始化与安全确认`. If the target drive was not provided, ask the user for a drive letter before initializing.
5. If it exists, read:
   - `README_WORKFLOW.md`
   - `workflow_state.json`
   - `workflow_log.md`
6. If the user provided a different target drive than the persisted one, stop and ask whether to create a new workflow workspace or reset the current state for the new drive.
7. Output a recovery summary containing:
   - workflow name
   - target drive
   - target root
   - system drive
   - last completed node
   - current node
   - next node
   - status
   - whether confirmation is required
   - notes for the next run
8. Continue according to `workflow_state.json`.

## State machine rule

Every node must follow this protocol:

```text
Read README_WORKFLOW.md
Read workflow_state.json
Validate target_drive, current node, and status
Read required snapshots
Run only this node's target-drive-scoped task
Write snapshot JSON if the node creates data
Write node_logs/<node>.md
Append workflow_log.md
Update workflow_state.json
Print a concise execution summary
Print what the next run should do
```

## Workflow nodes

Use the node definitions in `references/workflow.md`. The canonical sequence is:

```text
N0_恢复或初始化
N1_初始化与安全确认
N2_磁盘空间诊断
N3_目录占用分析
N4_大文件扫描
N5_生成清理候选清单
N6_低风险临时文件预览
N7_人工确认临时文件清理
N8_执行临时文件清理
N9_回收站检查
N10_人工确认回收站清理
N11_执行回收站清理
N12_Windows组件缓存分析
N13_人工确认组件缓存清理
N14_执行组件缓存清理
N15_开发环境缓存扫描
N16_开发缓存清理方案
N17_人工确认开发缓存清理
N18_执行开发缓存清理
N19_重复文件候选扫描
N20_大文件迁移方案
N21_人工确认文件迁移
N22_执行文件迁移
N23_清理后复查
N24_生成最终报告
```

## Confirmation rule

Confirmation must be exact text. Examples:

```text
确认清理临时文件
确认清空目标盘回收站
确认清理组件缓存
确认清理 pip 缓存
确认清理 npm 缓存
确认迁移 文件编号 1,3,5 到 E:\Backup，并保留目录结构
跳过
```

If the user provides unclear confirmation, do not execute destructive actions.

## Required response format after every node

```md
## 本节点执行完成

### 节点

<node name>

### 目标磁盘

<target_drive>

### 本次完成内容

<short summary>

### 生成文件

- <files>

### 更新状态

last_completed_node: <node>
next_node: <node>
status: <status>

### 关键信息

<facts from snapshots or command output only>

### 下一次继续时

<read state and continue from next node>

### 是否需要用户确认

需要 / 不需要
```
