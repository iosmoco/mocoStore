#!/bin/bash
set -euo pipefail

echo "Updating Sileo repo..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

REPO_DIR="repo"

(
  cd "$REPO_DIR"

  dpkg-scanpackages -m debs > Packages

  python3 <<'PY'
from pathlib import Path
import subprocess

packages_path = Path("Packages")
text = packages_path.read_text(encoding="utf-8")

entries = [e for e in text.strip().split("\n\n") if e.strip()]

def get_field(deb_path: str, field: str) -> str:
    result = subprocess.run(
        ["dpkg-deb", "-f", deb_path, field],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip()

# 各 deb から Package名 -> SileoDepiction URL を集める
sileo_map = {}
for deb in sorted(Path("debs").glob("*.deb")):
    pkg = get_field(str(deb), "Package")
    sdep = get_field(str(deb), "SileoDepiction")
    if pkg and sdep:
        sileo_map[pkg] = sdep

new_entries = []

for entry in entries:
    lines = entry.splitlines()
    package_name = None

    for line in lines:
        if line.startswith("Package: "):
            package_name = line.split(": ", 1)[1]
            break

    # 既存の Sileodepiction / SileoDepiction は一旦消す
    lines = [
        line for line in lines
        if not line.startswith("Sileodepiction:")
        and not line.startswith("SileoDepiction:")
    ]

    if package_name and package_name in sileo_map:
        # Name の直後に入れる。無ければ末尾に追加
        insert_index = len(lines)
        for i, line in enumerate(lines):
            if line.startswith("Name: "):
                insert_index = i + 1
                break
        lines.insert(insert_index, f"SileoDepiction: {sileo_map[package_name]}")

    new_entries.append("\n".join(lines))

packages_path.write_text("\n\n".join(new_entries) + "\n", encoding="utf-8")
PY

  gzip -kf Packages
)

git add .

if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m "repo update"
  git push
fi

echo "Repo updated!"