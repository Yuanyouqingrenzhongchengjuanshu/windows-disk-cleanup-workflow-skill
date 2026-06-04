# Windows 硬盘清理持久化状态机工作流

本文件是 `windows-disk-cleanup-workflow` skill 的完整工作流定义。执行时必须以 `workflow_state.json` 和 `snapshots/*.json` 为事实来源。

本工作流支持用户指定目标磁盘，例如 `C:`、`D:`、`E:`。除读取全局磁盘容量用于对比外，所有扫描、候选、清理、迁移建议都必须围绕 `target_drive` 执行。

## 1. 状态对象

`workflow_state.json` 必须包含以下字段：

```json
{
  "workflow_name": "windows_disk_cleanup_workflow",
  "version": "1.1",
  "created_at": "",
  "updated_at": "",
  "target_drive": "",
  "target_root": "",
  "system_drive": "",
  "current_node": "",
  "last_completed_node": "",
  "next_node": "",
  "status": "initialized | running | waiting_confirmation | completed | paused | error",
  "risk_level": "low | medium | high",
  "confirmation_required": false,
  "required_confirmation_text": "",
  "disk_before": {},
  "disk_after": {},
  "drive_inventory_snapshot": "snapshots/drive_inventory.json",
  "large_directories_snapshot": "snapshots/large_directories.json",
  "large_files_snapshot": "snapshots/large_files.json",
  "cleanup_candidates_snapshot": "snapshots/cleanup_candidates.json",
  "temp_preview_snapshot": "snapshots/temp_preview.json",
  "recycle_bin_preview_snapshot": "snapshots/recycle_bin_preview.json",
  "windows_update_preview_snapshot": "snapshots/windows_update_preview.json",
  "developer_cache_preview_snapshot": "snapshots/developer_cache_preview.json",
  "duplicate_candidates_snapshot": "snapshots/duplicate_candidates.json",
  "move_candidates_snapshot": "snapshots/move_candidates.json",
  "approved_actions": [],
  "executed_actions": [],
  "skipped_actions": [],
  "errors": [],
  "released_space_estimate": "",
  "released_space_actual": "",
  "notes_for_next_run": "",
  "integrity_check": {
    "state_file_exists": true,
    "readme_exists": true,
    "log_file_exists": true,
    "last_node_log_exists": true
  }
}
```

## 2. 目标磁盘规则

1. `target_drive` 必须是用户指定的有效盘符，格式统一为 `D:`。
2. `target_root` 必须是 `D:\` 这种根路径。
3. `system_drive` 从 `$env:SystemDrive` 获取，通常是 `C:`，但不得硬编码。
4. 如果用户没有指定目标磁盘，必须暂停并询问。
5. 如果用户指定的磁盘不存在，必须暂停并要求重新提供。
6. 如果用户想从 `D:` 切换到 `E:`，不要直接沿用旧状态。需要询问是新建工作流目录，还是重置当前工作流状态。
7. 所有节点输出都必须写明当前目标磁盘。

目标磁盘验证建议命令：

```powershell
$TargetDrive = "D:"
$TargetRoot = "$TargetDrive\"
$exists = Test-Path $TargetRoot
$SystemDrive = $env:SystemDrive
```

## 3. Recovery node

### N0_恢复或初始化

Actions:

1. Check default workspace path:

```powershell
$CleanupRoot = "$env:USERPROFILE\Desktop\windows_disk_cleanup_workflow"
Test-Path $CleanupRoot
```

2. If missing, ask for `target_drive` if not already supplied, then run initialization and set next node to `N1_初始化与安全确认`.
3. If present, read state, logs, and README.
4. Validate `target_drive` and `target_root`.
5. Print recovery summary including `target_drive`, `target_root`, and `system_drive`.
6. Route by status:

```text
missing state -> N1_初始化与安全确认
missing target_drive -> ask user for target drive
running -> execute next_node
waiting_confirmation -> wait for exact confirmation text
error -> stop and report
completed -> show final report location
```

## 4. Main nodes

### N1_初始化与安全确认

Goal: create workspace, safety files, logs, initial state, and persist the selected target drive.

Must create:

```text
README_WORKFLOW.md
workflow_state.json
workflow_log.md
node_logs/
snapshots/
commands/
```

README must state the selected target drive.

Set:

```json
{
  "target_drive": "D:",
  "target_root": "D:\\",
  "system_drive": "C:",
  "current_node": "N1_初始化与安全确认",
  "last_completed_node": "N1_初始化与安全确认",
  "next_node": "N2_磁盘空间诊断",
  "status": "running",
  "risk_level": "low",
  "confirmation_required": false,
  "notes_for_next_run": "下一次从 N2_磁盘空间诊断 开始，检查所有文件系统磁盘空间，并重点记录目标磁盘。"
}
```

### N2_磁盘空间诊断

Goal: collect all file-system drive capacity and mark the selected target drive.

Suggested command:

```powershell
Get-PSDrive -PSProvider FileSystem |
Select-Object Name, Used, Free, @{Name="Total";Expression={$_.Used + $_.Free}}
```

Write:

```text
snapshots/drive_inventory.json
snapshots/disk_before.json
node_logs/N2_磁盘空间诊断.md
```

`disk_before` must include the target drive's total, used, free, and free percent.

Next: `N3_目录占用分析`.

### N3_目录占用分析

Goal: analyze major directories on the selected target drive.

Targets:

1. Enumerate top-level directories under `target_root`, such as `D:\*`.
2. If `target_drive == system_drive`, also classify these protected paths explicitly:

```text
%SystemDrive%\Windows
%SystemDrive%\Program Files
%SystemDrive%\Program Files (x86)
%SystemDrive%\ProgramData
%SystemDrive%\Users
```

3. If the current user's profile is located on the target drive, analyze these user folders:

```text
$env:USERPROFILE\Desktop
$env:USERPROFILE\Downloads
$env:USERPROFILE\Documents
$env:USERPROFILE\Pictures
$env:USERPROFILE\Videos
$env:USERPROFILE\AppData
```

4. If the current user's profile is not on the target drive, do not scan those folders in this node.

Write `snapshots/large_directories.json`.

Classify each as:

```text
safe_candidate
needs_confirmation
do_not_touch
```

Protected system and installation directories must be `do_not_touch`.

Next: `N4_大文件扫描`.

### N4_大文件扫描

Goal: list files above 500MB on the selected target drive while excluding protected system and installation directories.

Scan root:

```text
target_root
```

Skip if present on target drive:

```text
<target_root>Windows
<target_root>Program Files
<target_root>Program Files (x86)
<target_root>System Volume Information
<target_root>$Recycle.Bin
```

Do not delete. Write `snapshots/large_files.json`.

Each record must include:

```json
{
  "target_drive": "D:",
  "path": "",
  "size_bytes": 0,
  "size_human": "",
  "modified_time": "",
  "suggestion": "保留 | 可考虑移动 | 需要人工判断"
}
```

Next: `N5_生成清理候选清单`.

### N5_生成清理候选清单

Goal: build target-drive cleanup candidate table from prior snapshots.

Risk categories:

```text
低风险: target-drive scoped temp folders, thumbnail cache, DirectX shader cache, browser cache when cache path is on target_drive
中风险: npm/pip/conda/Maven/Gradle caches on target_drive, Docker unused images/build cache when Docker storage is on target_drive
高风险: node_modules, Docker volumes, Downloads, source code, virtual environments, personal files
```

Write `snapshots/cleanup_candidates.json`.

Next: `N6_低风险临时文件预览`.

### N6_低风险临时文件预览

Goal: preview temporary files older than 7 days that are within the selected target drive.

Candidate targets:

1. `$env:TEMP` only if it starts with `target_root`.
2. `<system_drive>\Windows\Temp` only if `target_drive == system_drive`.
3. Existing temp-like directories discovered under `target_root`, such as:

```text
<target_root>Temp
<target_root>TEMP
<target_root>tmp
```

No deletion. Write `snapshots/temp_preview.json`.

If no target-drive temp locations are found, write an empty preview and route to `N9_回收站检查`, recording a skipped confirmation because there is nothing to clean.

If preview has candidates, next state must be waiting confirmation at `N7_人工确认临时文件清理`.

### N7_人工确认临时文件清理

Set:

```json
{
  "current_node": "N7_人工确认临时文件清理",
  "status": "waiting_confirmation",
  "confirmation_required": true,
  "required_confirmation_text": "确认清理临时文件",
  "next_node": "N8_执行临时文件清理"
}
```

If user says `跳过`, route to `N9_回收站检查` and append skipped action.

### N8_执行临时文件清理

Only delete files listed in `snapshots/temp_preview.json` that still match the preview criteria and are under `target_root`. Skip locked files. Record success, failure, and actual released space.

Next: `N9_回收站检查`.

### N9_回收站检查

Goal: estimate recycle bin usage for the selected target drive. No clearing.

Possible target path:

```text
<target_root>$Recycle.Bin
```

Write `snapshots/recycle_bin_preview.json`.

Next: `N10_人工确认回收站清理`.

### N10_人工确认回收站清理

Required confirmation text:

```text
确认清空目标盘回收站
```

If skipped, route to `N12_Windows组件缓存分析`.

### N11_执行回收站清理

Use a target-drive scoped command where supported:

```powershell
Clear-RecycleBin -DriveLetter D -Force
```

Do not use a global recycle-bin clear unless the user separately confirms global clearing.

Record outcome. Next: `N12_Windows组件缓存分析`.

### N12_Windows组件缓存分析

This node only applies when `target_drive == system_drive`.

If `target_drive != system_drive`, skip this node and record:

```json
{
  "action": "windows_component_store_analysis",
  "status": "skipped",
  "reason": "target_drive_is_not_system_drive"
}
```

Then route directly to `N15_开发环境缓存扫描`.

If target drive is the system drive, run:

```powershell
DISM /Online /Cleanup-Image /AnalyzeComponentStore
```

No cleanup. Write `snapshots/windows_update_preview.json`.

Next: `N13_人工确认组件缓存清理`.

### N13_人工确认组件缓存清理

Required confirmation text:

```text
确认清理组件缓存
```

If skipped, route to `N15_开发环境缓存扫描`.

### N14_执行组件缓存清理

Allowed only when `target_drive == system_drive`.

Allowed command:

```powershell
DISM /Online /Cleanup-Image /StartComponentCleanup
```

Forbidden unless separately requested:

```text
/ResetBase
```

Next: `N15_开发环境缓存扫描`.

### N15_开发环境缓存扫描

Scan only. Do not clean.

Targets must be included only when their cache path is on `target_drive`, or when the tool reports storage located on `target_drive`.

Targets:

```text
npm cache
pnpm store
yarn cache
pip cache
conda cache
Maven .m2
Gradle .gradle
Docker images/build cache/containers/volumes summary
JetBrains cache
VS Code cache
node_modules
Python virtual environments
```

For Docker, use reporting commands only such as:

```powershell
docker system df
```

If Docker root is not known to be on `target_drive`, mark Docker cleanup as `needs_confirmation` and do not assume it affects the target drive.

Write `snapshots/developer_cache_preview.json`.

Next: `N16_开发缓存清理方案`.

### N16_开发缓存清理方案

Generate target-drive scoped cleanup plan with columns:

```text
工具 | 路径 | 占用空间 | 可否重新生成 | 风险 | 推荐命令 | 是否在目标盘 | 是否需要确认
```

Do not recommend cleaning a cache that is not on the selected target drive unless the user explicitly asks for global cleanup.

Next: `N17_人工确认开发缓存清理`.

### N17_人工确认开发缓存清理

Each confirmation handles one category only.

Examples:

```text
确认清理 pip 缓存
确认清理 npm 缓存
确认清理 conda 缓存
确认清理 Docker 构建缓存
跳过开发缓存清理
```

If confirmed, route to `N18_执行开发缓存清理`.
If skipped, route to `N19_重复文件候选扫描`.

### N18_执行开发缓存清理

Run only the category confirmed in N17, and only when the planned target path is on `target_drive` or the user explicitly confirms global cleanup. After execution, return to N17 until skipped.

### N19_重复文件候选扫描

Scan only files on the selected target drive.

Default scan root:

```text
target_root
```

Skip protected folders:

```text
<target_root>Windows
<target_root>Program Files
<target_root>Program Files (x86)
<target_root>System Volume Information
<target_root>$Recycle.Bin
```

Only files above 100MB. Do not delete.

Write `snapshots/duplicate_candidates.json`.

Next: `N20_大文件迁移方案`.

### N20_大文件迁移方案

Create a move plan from target-drive large-file and duplicate-file snapshots. Do not move.

The suggested target location must not be the same as `target_drive`, unless the user explicitly asks to reorganize files within the same drive.

Write `snapshots/move_candidates.json`.

Next: `N21_人工确认文件迁移`.

### N21_人工确认文件迁移

Confirmation format:

```text
确认迁移 文件编号 1,3,5 到 E:\Backup，并保留目录结构
```

If skipped, route to `N23_清理后复查`.

### N22_执行文件迁移

Requirements:

1. Check target destination drive free space.
2. Destination drive should usually be different from `target_drive`.
3. Preserve original directory structure if requested.
4. Verify file size after move.
5. Keep source file if verification fails.
6. Write migration log.

Next: `N23_清理后复查`.

### N23_清理后复查

Re-read drive capacity and compare the selected target drive with `disk_before`.

Write:

```text
snapshots/disk_after.json
```

Next: `N24_生成最终报告`.

### N24_生成最终报告

Create final report:

```text
windows_disk_cleanup_workflow/final_report.md
```

Report sections:

```md
# Windows 硬盘清理最终报告

## 1. 目标磁盘
## 2. 清理前磁盘状态
## 3. 清理后磁盘状态
## 4. 实际释放空间
## 5. 已执行操作
## 6. 跳过操作
## 7. 失败操作
## 8. 高风险候选项
## 9. 大文件建议
## 10. 后续建议
## 11. 风险总结
```

Set workflow status to `completed`.

## 5. Anti-hallucination checks

Before making a claim, verify it from files:

```text
Claim about target drive -> workflow_state.json target_drive and target_root
Claim about current node -> workflow_state.json
Claim about disk space -> snapshots/disk_before.json or snapshots/disk_after.json
Claim about candidates -> corresponding snapshots/*.json
Claim about executed action -> workflow_state.json executed_actions and workflow_log.md
Claim about skipped action -> workflow_state.json skipped_actions
```

If evidence is missing, say the information is not available and stop.
