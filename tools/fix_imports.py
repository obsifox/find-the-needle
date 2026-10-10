#!/usr/bin/env python3
"""Repair pass AFTER Godot's --import step.

The editor rewrites some of the recovered-asset .import files to the
standard ".godot/imported/<name>-<md5(path)>.<ext>" layout (it cannot
actually import them -- the raw sources were stripped from the v1.3.0
tree -- but it still rewrites the remap).  The compiled artifacts DO
exist in the repo under compiled/ folders, so this script copies each
artifact to the exact path the rewritten .import now points at.

Runs as part of the build pipeline:  import -> fix_imports -> export
Deterministic: the hash in the rewritten path is md5 of the source path.
"""
import os
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_remap_target(path: str) -> str | None:
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("path="):
                    return line.strip()[len('path="'):-1]
    except OSError:
        return None
    return None


def read_import_path(path: str) -> str | None:
    try:
        with open(path, "r", encoding="utf-8") as f:
            in_remap = False
            for line in f:
                s = line.strip()
                if s == "[remap]":
                    in_remap = True
                elif s.startswith("["):
                    in_remap = False
                elif in_remap and s.startswith("path="):
                    return s[len('path="'):-1]
    except OSError:
        return None
    return None


def main() -> None:
    fixed = 0
    already = 0
    missing_artifact = 0
    for root, _dirs, files in os.walk(REPO):
        if "/.git" in root or "/.godot" in root:
            continue
        for fn in files:
            if not fn.endswith(".remap"):
                continue
            remap_path = os.path.join(root, fn)
            target = read_remap_target(remap_path)
            if target is None:
                continue
            import_path = remap_path[:-len(".remap")] + ".import"
            cur = read_import_path(import_path)
            if cur is None:
                continue
            if cur == target:
                already += 1
                continue
            if not cur.startswith("res://.godot/imported/"):
                print(f"[fix] unexpected import path for {remap_path}: {cur}")
                continue
            artifact_abs = os.path.join(REPO, target[len("res://"):])
            dest_abs = os.path.join(REPO, cur[len("res://"):])
            if not os.path.exists(artifact_abs):
                print(f"[fix] MISSING artifact {artifact_abs}")
                missing_artifact += 1
                continue
            os.makedirs(os.path.dirname(dest_abs), exist_ok=True)
            shutil.copy2(artifact_abs, dest_abs)
            fixed += 1
    print(f"[fix] rewrote-need fixed: {fixed}, already ok: {already}, missing: {missing_artifact}")
    if missing_artifact:
        sys.exit(1)


if __name__ == "__main__":
    main()
