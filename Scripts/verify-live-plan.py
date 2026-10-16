#!/usr/bin/env python3
"""Fail if a live --dry-run plan would force-quit the macOS session."""

import json
import sys

report = json.load(sys.stdin)
protected = {item.lower() for item in report["protectedBundleIdentifiers"]}
own_pid = report["ownProcessIdentifier"]
targets = report["targets"]

problems = []
for target in targets:
    bundle = (target.get("bundleIdentifier") or "").lower()
    if target["processIdentifier"] == own_pid:
        problems.append(f"own process {own_pid} is a target")
    if bundle and (bundle in protected or bundle == "com.apple.dock" or bundle.startswith("com.apple.dock.")):
        problems.append(f"protected app is a target: {bundle}")
    if target.get("activationPolicy") != "regular":
        problems.append(f"non-regular target: {target}")
    if target.get("reason") is not None:
        problems.append(f"target has a skip reason: {target}")

skipped = {(item.get("bundleIdentifier") or "").lower(): item.get("reason") for item in report["skipped"]}
if skipped.get("com.apple.finder") != "protectedSystem":
    problems.append(f"Finder was not protected: {skipped.get('com.apple.finder')}")

if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)

names = ", ".join(target["name"] for target in targets) or "(none)"
print(f"live plan ok: {len(targets)} apps would quit ({names})")
