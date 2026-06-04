# Windows Disk Cleanup Workflow Skill

[中文](./README.zh-CN.md) | English

A Codex Skill for safely cleaning a user-specified Windows drive through a persistent, resumable state machine.

## Overview

This Skill helps Codex inspect and clean Windows disk space in a conservative workflow. It does not assume the target is `C:`. The user can choose `C:`, `D:`, `E:`, or another valid Windows filesystem drive.

The workflow persists progress to local files, so Codex can resume from the previous node instead of relying on chat context.

## Key features

- Target-drive scoped cleanup, such as `C:`, `D:`, or `E:`
- Persistent state stored in `workflow_state.json`
- Node-by-node state machine execution
- JSON snapshots for scan results
- Markdown node logs and full workflow logs
- Confirmation gates before cleanup, move, recycle bin emptying, or component cleanup
- Recovery protocol for interrupted sessions
- Conservative handling of personal files, source code, downloads, virtual environments, and Docker volumes

## Skill structure

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

## Install locally for Codex

Copy the folder into your Codex skills directory.

```powershell
mkdir $env:USERPROFILE\.codex\skills -Force
Copy-Item .\windows-disk-cleanup-workflow-skill $env:USERPROFILE\.codex\skills\windows-disk-cleanup-workflow -Recurse -Force
```

## Start from Codex

Invoke the Skill and specify the target drive.

```text
$windows-disk-cleanup-workflow
Start the persistent Windows disk cleanup state-machine workflow. The target drive is D:.
```

You can also use Chinese:

```text
$windows-disk-cleanup-workflow
请启动 Windows 硬盘清理持久化状态机工作流，目标磁盘是 D:。
```

## Bootstrap the workspace manually

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -TargetDrive D:
```

The bootstrap script creates the workflow workspace on the desktop:

```text
%USERPROFILE%\Desktop\windows_disk_cleanup_workflow
```

## Persistent workflow files

```text
windows_disk_cleanup_workflow/
├─ README_WORKFLOW.md
├─ workflow_state.json
├─ workflow_log.md
├─ node_logs/
├─ snapshots/
└─ commands/
```

Purpose of each file or directory:

| Path | Purpose |
|---|---|
| `README_WORKFLOW.md` | Records the workflow rules and node sequence |
| `workflow_state.json` | Stores the current node, target drive, confirmation status, and next action |
| `workflow_log.md` | Stores the full timeline of workflow execution |
| `node_logs/` | Stores one human-readable log per node |
| `snapshots/` | Stores factual scan results as JSON |
| `commands/` | Stores proposed, executed, and skipped commands |

## Safety model

This Skill is intentionally conservative:

1. It scans before it cleans.
2. It previews before it executes.
3. It requires exact confirmation text before risky actions.
4. It does not automatically delete personal files.
5. It does not edit the registry.
6. It does not directly delete Windows core folders or installed application folders.
7. It does not automatically prune Docker volumes.
8. It records errors instead of claiming success.

## Target-drive behavior

The selected drive is persisted in `workflow_state.json` as:

```json
{
  "target_drive": "D:",
  "target_root": "D:\\",
  "system_drive": "C:"
}
```

If a later run specifies a different drive, the Skill must stop and ask whether to create a new workflow or reset the current state. This prevents mixing scan results from different drives.

## Typical workflow

```text
N0 Restore or initialize
N1 Initialize and confirm safety rules
N2 Diagnose disk space
N3 Analyze target-drive directory usage
N4 Scan large files on the target drive
N5 Generate cleanup candidates
N6 Preview low-risk temporary files
N7 Wait for confirmation
N8 Execute confirmed cleanup
...
N24 Generate final report
```

See [`references/workflow.md`](./references/workflow.md) for the full state machine.

## Recommended GitHub usage

Use `README.md` as the English landing page and `README.zh-CN.md` as the Chinese landing page. GitHub strips custom JavaScript from Markdown, so language switching is implemented with normal Markdown links at the top of both files.
