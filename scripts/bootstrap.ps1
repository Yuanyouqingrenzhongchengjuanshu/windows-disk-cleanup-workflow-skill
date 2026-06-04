<#
.SYNOPSIS
Initializes the persistent Windows disk cleanup workflow workspace.

.DESCRIPTION
Creates the default Desktop workspace, baseline README, workflow_state.json,
workflow_log.md, and required subdirectories. This script does not delete,
move, clean, prune, or modify user/system files outside the workflow folder.

The workflow is scoped to a user-selected target drive, such as C:, D:, or E:.
#>

param(
    [string]$CleanupRoot = "$env:USERPROFILE\Desktop\windows_disk_cleanup_workflow",
    [Parameter(Mandatory = $true)]
    [string]$TargetDrive
)

$ErrorActionPreference = "Stop"
$now = (Get-Date).ToString("s")

function Normalize-DriveLetter {
    param([string]$Drive)
    $d = $Drive.Trim()
    if ($d.EndsWith("\")) { $d = $d.TrimEnd("\") }
    if (-not $d.EndsWith(":")) { $d = "${d}:" }
    return $d.ToUpperInvariant()
}

$TargetDrive = Normalize-DriveLetter -Drive $TargetDrive
$TargetRoot = "$TargetDrive\"
$SystemDrive = (Normalize-DriveLetter -Drive $env:SystemDrive)

if (-not (Test-Path $TargetRoot)) {
    throw "Target drive does not exist or is not accessible: $TargetRoot"
}

New-Item -ItemType Directory -Force $CleanupRoot | Out-Null
New-Item -ItemType Directory -Force "$CleanupRoot\node_logs" | Out-Null
New-Item -ItemType Directory -Force "$CleanupRoot\snapshots" | Out-Null
New-Item -ItemType Directory -Force "$CleanupRoot\commands" | Out-Null

$readme = @"
# Windows 硬盘清理工作流说明

## 工作流目标

安全清理 Windows 指定磁盘空间。

## 当前目标磁盘

- target_drive: $TargetDrive
- target_root: $TargetRoot
- system_drive: $SystemDrive

## 核心原则

1. 先扫描，后清理。
2. 先预览，后执行。
3. 先确认，后删除。
4. 所有操作围绕目标磁盘执行。
5. 不删除个人文件。
6. 不清理注册表。
7. 不直接操作系统核心目录。
8. 所有结果必须持久化。
9. 如果目标磁盘不是系统盘，自动跳过 Windows 组件缓存清理。

## 恢复规则

每次继续执行前，必须先读取 workflow_state.json。
如果 current_node 是确认节点，则等待用户确认。
如果 last_completed_node 存在，则从 next_node 继续。
如果状态不完整，不得继续执行。
如果用户想更换目标磁盘，不得直接沿用旧状态，需要询问是否新建或重置流程。
"@

Set-Content -Path "$CleanupRoot\README_WORKFLOW.md" -Value $readme -Encoding UTF8

$state = [ordered]@{
    workflow_name = "windows_disk_cleanup_workflow"
    version = "1.1"
    created_at = $now
    updated_at = $now
    target_drive = $TargetDrive
    target_root = $TargetRoot
    system_drive = $SystemDrive
    current_node = "N1_初始化与安全确认"
    last_completed_node = "N1_初始化与安全确认"
    next_node = "N2_磁盘空间诊断"
    status = "running"
    risk_level = "low"
    confirmation_required = $false
    required_confirmation_text = ""
    disk_before = @{}
    disk_after = @{}
    drive_inventory_snapshot = "snapshots/drive_inventory.json"
    large_directories_snapshot = "snapshots/large_directories.json"
    large_files_snapshot = "snapshots/large_files.json"
    cleanup_candidates_snapshot = "snapshots/cleanup_candidates.json"
    temp_preview_snapshot = "snapshots/temp_preview.json"
    recycle_bin_preview_snapshot = "snapshots/recycle_bin_preview.json"
    windows_update_preview_snapshot = "snapshots/windows_update_preview.json"
    developer_cache_preview_snapshot = "snapshots/developer_cache_preview.json"
    duplicate_candidates_snapshot = "snapshots/duplicate_candidates.json"
    move_candidates_snapshot = "snapshots/move_candidates.json"
    approved_actions = @()
    executed_actions = @()
    skipped_actions = @()
    errors = @()
    released_space_estimate = ""
    released_space_actual = ""
    notes_for_next_run = "下一次从 N2_磁盘空间诊断 开始，检查所有文件系统磁盘空间，并重点记录目标磁盘 $TargetDrive。"
    integrity_check = [ordered]@{
        state_file_exists = $true
        readme_exists = $true
        log_file_exists = $true
        last_node_log_exists = $false
    }
}

$state | ConvertTo-Json -Depth 8 | Set-Content -Path "$CleanupRoot\workflow_state.json" -Encoding UTF8

$log = @"
# Windows 硬盘清理工作流日志

## $now

### 节点

N1_初始化与安全确认

### 目标磁盘

$TargetDrive

### 执行内容

创建持久化工作目录和初始状态文件。工作流已绑定目标磁盘 $TargetRoot。

### 状态变化

last_completed_node: N1_初始化与安全确认
next_node: N2_磁盘空间诊断
status: running

### 下次继续时应做什么

从 N2_磁盘空间诊断 开始，先读取 workflow_state.json，并围绕目标磁盘 $TargetDrive 继续。
"@

Set-Content -Path "$CleanupRoot\workflow_log.md" -Value $log -Encoding UTF8
Set-Content -Path "$CleanupRoot\commands\proposed_commands.md" -Value "# Proposed commands`n" -Encoding UTF8
Set-Content -Path "$CleanupRoot\commands\executed_commands.md" -Value "# Executed commands`n" -Encoding UTF8
Set-Content -Path "$CleanupRoot\commands\skipped_commands.md" -Value "# Skipped commands`n" -Encoding UTF8

Write-Host "Initialized workflow workspace: $CleanupRoot"
Write-Host "Target drive: $TargetDrive"
Write-Host "Target root: $TargetRoot"
Write-Host "System drive: $SystemDrive"
Write-Host "Next node: N2_磁盘空间诊断"
