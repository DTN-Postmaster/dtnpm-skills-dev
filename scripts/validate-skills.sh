#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Checking shell scripts syntax"
bash -n scripts/validate-skills.sh
bash -n scripts/install-hooks.sh

echo "==> Validating skills manifests and SKILL.md files"
python3 - <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(".")

# 1. Validate JSON manifests
for manifest_rel in ("skills.json", ".agents/skills.json"):
    manifest_path = root / manifest_rel
    if not manifest_path.is_file():
        print(f"ERROR: Missing manifest {manifest_rel}", file=sys.stderr)
        sys.exit(1)
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: Invalid JSON in {manifest_rel}: {exc}", file=sys.stderr)
        sys.exit(1)
    entries = data.get("entries")
    if not isinstance(entries, list) or not entries:
        print(f"ERROR: {manifest_rel} must declare a non-empty 'entries' list", file=sys.stderr)
        sys.exit(1)
    if not any(isinstance(e, dict) and e.get("path") == "skills" for e in entries):
        print(f"ERROR: {manifest_rel} must reference path 'skills'", file=sys.stderr)
        sys.exit(1)

# 2. Validate skills directory structure and frontmatter
skills_dir = root / "skills"
if not skills_dir.is_dir():
    print("ERROR: Missing skills/ directory", file=sys.stderr)
    sys.exit(1)

skill_dirs = sorted(p for p in skills_dir.iterdir() if p.is_dir())
if not skill_dirs:
    print("ERROR: No skill directories found under skills/", file=sys.stderr)
    sys.exit(1)

name_re = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
placeholder_re = re.compile(r"\b(TO" + r"DO|FIX" + r"ME|XX" + r"X)\b")

for sdir in skill_dirs:
    skill_md = sdir / "SKILL.md"
    if not skill_md.is_file():
        print(f"ERROR: Missing SKILL.md in {sdir}", file=sys.stderr)
        sys.exit(1)

    content = skill_md.read_text(encoding="utf-8")
    lines = content.splitlines()
    if not lines or lines[0].strip() != "---":
        print(f"ERROR: {skill_md} must start with YAML frontmatter '---'", file=sys.stderr)
        sys.exit(1)

    end_idx = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is None:
        print(f"ERROR: {skill_md} has unterminated YAML frontmatter", file=sys.stderr)
        sys.exit(1)

    fm_lines = lines[1:end_idx]
    body = "\n".join(lines[end_idx + 1 :]).strip()
    if not body:
        print(f"ERROR: {skill_md} has an empty markdown body", file=sys.stderr)
        sys.exit(1)

    # Minimal strict YAML subset parser for name and description (single-line or block scalar)
    fm = {}
    i = 0
    while i < len(fm_lines):
        line = fm_lines[i]
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not m:
            print(f"ERROR: Invalid frontmatter line in {skill_md}: {line}", file=sys.stderr)
            sys.exit(1)
        key, val = m.group(1), m.group(2).strip()
        if val in (">-", ">", "|", "|-"):
            block_lines = []
            i += 1
            while i < len(fm_lines) and (fm_lines[i].startswith("  ") or not fm_lines[i].strip()):
                block_lines.append(fm_lines[i].strip())
                i += 1
            fm[key] = " ".join(x for x in block_lines if x).strip()
        else:
            if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            fm[key] = val
            i += 1

    name = fm.get("name", "")
    desc = fm.get("description", "")
    if name != sdir.name:
        print(f"ERROR: {skill_md} frontmatter name '{name}' does not match directory '{sdir.name}'", file=sys.stderr)
        sys.exit(1)
    if not name_re.match(name):
        print(f"ERROR: {skill_md} invalid skill name '{name}' (use lowercase kebab-case)", file=sys.stderr)
        sys.exit(1)
    if not desc or len(desc) > 1024:
        print(f"ERROR: {skill_md} description must be 1..1024 chars (got {len(desc)})", file=sys.stderr)
        sys.exit(1)

    if placeholder_re.search(content):
        print(f"ERROR: {skill_md} contains unfinished placeholder markers", file=sys.stderr)
        sys.exit(1)

    print(f"  OK  {skill_md} ({len(lines)} lines)")

print(f"Validated {len(skill_dirs)} skill(s) successfully.")
PY

echo "==> Checking GitHub Actions SHA pinning"
if grep -rnE 'uses:\s+[^@]+@(main|master|v[0-9]+)' .github/workflows/ >/dev/null 2>&1; then
  echo "ERROR: Unpinned GitHub Action reference detected in .github/workflows/" >&2
  exit 1
fi

echo "==> All checks passed."
