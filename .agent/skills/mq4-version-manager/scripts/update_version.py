#!/usr/bin/env python3
import argparse
import re
import os
import sys


def get_current_version(mq4_path):
    with open(mq4_path, "r", encoding="utf-8") as f:
        content = f.read()
    match = re.search(r'#property version\s+"(\d+\.\d+)"', content)
    if match:
        return float(match.group(1)), content
    return None, content


def update_mq4_version(mq4_path, new_version, content):
    new_ver_str = f"{new_version:.2f}"
    new_content = re.sub(
        r'(#property version\s+)"\d+\.\d+"', f'\\1"{new_ver_str}"', content
    )
    with open(mq4_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    return new_ver_str


def update_readme(readme_path, new_ver_str, desc, change_type):
    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Update Title Version
    # Match: # QuantTrader Pro (Version 1.0 Final)
    # The "Final" might be dynamic, let's just replace the version number part if possible,
    # or reconstruct the string.
    # The regex checks for # QuantTrader Pro (Version ...
    # Use \g<1> to separate group reference from the digits in new_ver_str
    content = re.sub(
        r"(# QuantTrader Pro \(Version )[\d+\.]+(.*?\))",
        f"\\g<1>{new_ver_str}\\g<2>",
        content,
    )

    # 2. Add to History
    # Find "## 版本历史"
    history_header = "## 版本历史"
    if history_header not in content:
        print(f"Warning: '{history_header}' not found in README.md")
        return

    # Entry format: *   **v1.1**: Description.
    new_entry = f"*   **v{new_ver_str}**: {desc}"

    # Insert after the header line
    lines = content.splitlines()
    new_lines = []
    found_history = False
    inserted = False

    for line in lines:
        new_lines.append(line)
        if history_header in line and not inserted:
            new_lines.append(new_entry)
            inserted = True

    with open(readme_path, "w", encoding="utf-8") as f:
        f.write("\n".join(new_lines))


def main():
    parser = argparse.ArgumentParser(description="Update QuantTrader Pro version")
    parser.add_argument(
        "--type", choices=["major", "minor", "patch"], required=True, help="Update type"
    )
    parser.add_argument("--desc", required=True, help="Version description")
    parser.add_argument("--path", default=".", help="Project root path")

    args = parser.parse_args()

    mq4_file = os.path.join(args.path, "QuantTrader_Pro.mq4")
    readme_file = os.path.join(args.path, "README.md")

    if not os.path.exists(mq4_file) or not os.path.exists(readme_file):
        print("Error: Files not found.")
        sys.exit(1)

    current_ver, mq4_content = get_current_version(mq4_file)
    if current_ver is None:
        print("Error: Could not find version in MQ4 file.")
        sys.exit(1)

    if args.type == "major":
        new_ver = int(current_ver) + 1.0
    elif args.type == "minor":
        new_ver = current_ver + 0.1
    else:  # patch
        new_ver = current_ver + 0.01

    new_ver_str = update_mq4_version(mq4_file, new_ver, mq4_content)
    update_readme(readme_file, new_ver_str, args.desc, args.type)

    print(f"Updated version to {new_ver_str}")


if __name__ == "__main__":
    main()
