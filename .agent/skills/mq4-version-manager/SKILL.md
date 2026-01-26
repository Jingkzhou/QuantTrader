---
name: mq4-version-manager
description: Automate QuantTrader Pro versioning. Use this skill when you have modified `QuantTrader_Pro.mq4` and need to increment the version number and update the changelog in `README.md`.
---

# MQ4 Version Manager

This skill helps manage the versioning of the QuantTrader Pro project. It automatically updates the version number in the source code and adds a changelog entry to the README.

## Usage

When you have completed a code change or a bug fix, use the `run_command` tool to execute the `update_version.py` script located in the `scripts` directory of this skill.

### Command Syntax

```bash
python3 .agent/skills/mq4-version-manager/scripts/update_version.py --type [major|minor|patch] --desc "Your description here" --path .
```

### Arguments

- `--type`:
    - `major`: Increments the major version (e.g., 1.0 -> 2.0).
    - `minor`: Increments the minor version (e.g., 1.0 -> 1.1). Use for new features.
    - `patch`: Increments the patch version (e.g., 1.0 -> 1.01). Use for bug fixes.
- `--desc`: A brief description of the changes. This will be added to `README.md`. **MUST be in Chinese (Simplified).**
- `--path`: The root directory of the project (usually `.`).

## Examples

**Example 1: Bug Fix (Patch)**
User: "I fixed the web request timeout bug."
Action:
```bash
python3 .agent/skills/mq4-version-manager/scripts/update_version.py --type patch --desc "修复: 优化了网络请求超时问题" --path .
```

**Example 2: New Feature (Minor)**
User: "Added a new RSI filter."
Action:
```bash
python3 .agent/skills/mq4-version-manager/scripts/update_version.py --type minor --desc "新增: 添加 RSI 过滤逻辑" --path .
```
