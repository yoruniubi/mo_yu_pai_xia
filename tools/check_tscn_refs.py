#!/usr/bin/env python3
"""
检查 Godot .tscn 场景文件中的资源引用是否完整。

功能：
1) 检查 SubResource("...") 是否都有对应 [sub_resource ... id="..."] 定义。
2) 检查 ExtResource("...") 是否都有对应 [ext_resource ... id="..."] 定义。
3) （可选）检查 [gd_scene load_steps=N] 是否与资源数量大致一致。

注意：
- load_steps 在不同 Godot 版本/保存状态下可能存在差异，
  因此默认不做严格警告，避免误报。
- 核心价值是发现“引用了不存在资源 ID”这类会导致解析失败的问题。

用法（在项目根目录执行）：
    python tools/check_tscn_refs.py

可选：
    python tools/check_tscn_refs.py --check-load-steps
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


GD_SCENE_LOAD_STEPS_RE = re.compile(r"\[gd_scene\s+load_steps=(\d+)")
SUB_DEF_RE = re.compile(r"\[sub_resource[^\]]*id=\"([^\"]+)\"\]")
SUB_REF_RE = re.compile(r"SubResource\(\"([^\"]+)\"\)")
EXT_DEF_RE = re.compile(r"\[ext_resource[^\]]*id=\"([^\"]+)\"\]")
EXT_REF_RE = re.compile(r"ExtResource\(\"([^\"]+)\"\)")


def check_scene_file(
    path: Path,
    check_load_steps: bool,
) -> tuple[list[str], list[str], str | None]:
    text = path.read_text(encoding="utf-8")

    sub_defs = set(SUB_DEF_RE.findall(text))
    sub_refs = set(SUB_REF_RE.findall(text))
    ext_defs = set(EXT_DEF_RE.findall(text))
    ext_refs = set(EXT_REF_RE.findall(text))

    missing_sub = sorted(sub_refs - sub_defs)
    missing_ext = sorted(ext_refs - ext_defs)

    load_steps_warning = None
    if check_load_steps:
        m = GD_SCENE_LOAD_STEPS_RE.search(text)
        if m:
            declared = int(m.group(1))
            # 经验值：通常为 ext + sub + 1（主场景本身）
            expected = len(sub_defs) + len(ext_defs) + 1
            if declared != expected:
                load_steps_warning = (
                    f"load_steps={declared} 可能不一致，按经验值推算约为 {expected}"
                )

    return missing_sub, missing_ext, load_steps_warning


def main() -> int:
    parser = argparse.ArgumentParser(
        description="检查 Godot .tscn 场景资源引用完整性"
    )
    parser.add_argument(
        "--check-load-steps",
        action="store_true",
        help="额外检查 load_steps（仅经验性提示，可能存在误报）",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    scenes_dir = project_root / "Scenes"

    if not scenes_dir.exists():
        print(f"未找到目录: {scenes_dir}")
        return 2

    scene_files = sorted(scenes_dir.rglob("*.tscn"))
    if not scene_files:
        print("Scenes 目录下没有找到 .tscn 文件")
        return 0

    has_error = False
    has_warning = False

    print(f"扫描 {len(scene_files)} 个场景文件: {scenes_dir}")
    for path in scene_files:
        missing_sub, missing_ext, load_steps_warning = check_scene_file(
            path,
            check_load_steps=args.check_load_steps,
        )
        rel = path.relative_to(project_root)

        if missing_sub or missing_ext:
            has_error = True
            print(f"\n[ERROR] {rel}")
            if missing_sub:
                print("  缺失 SubResource 定义:", ", ".join(missing_sub))
            if missing_ext:
                print("  缺失 ExtResource 定义:", ", ".join(missing_ext))

        if load_steps_warning:
            has_warning = True
            print(f"\n[WARN]  {rel}")
            print(f"  {load_steps_warning}")

    print("\n---")
    if has_error:
        print("检查完成：发现引用错误（ERROR）。请先修复后再运行游戏。")
        return 1

    if has_warning:
        print("检查完成：未发现引用错误，但有 load_steps 提示（WARN，可能误报）。")
        return 0

    print("检查完成：未发现缺失的 SubResource/ExtResource 引用。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
