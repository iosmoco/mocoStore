#!/bin/bash
set -euo pipefail

echo "Updating Sileo repo..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

REPO_DIR="repo"
DEPICTION_DIR="$REPO_DIR/depiction"
JSON_OUT="$DEPICTION_DIR/moco.json"
BASE_URL="https://iosmoco.github.io/mocostore/repo"

mkdir -p "$DEPICTION_DIR"

LATEST_DEB="$(ls -t "$REPO_DIR"/debs/*.deb | head -n 1)"
echo "Using latest deb: $LATEST_DEB"

PACKAGE="$(dpkg-deb -f "$LATEST_DEB" Package 2>/dev/null || true)"
NAME="$(dpkg-deb -f "$LATEST_DEB" Name 2>/dev/null || true)"
VERSION="$(dpkg-deb -f "$LATEST_DEB" Version 2>/dev/null || true)"
DESCRIPTION="$(dpkg-deb -f "$LATEST_DEB" Description 2>/dev/null || true)"
AUTHOR="$(dpkg-deb -f "$LATEST_DEB" Author 2>/dev/null || true)"
SECTION="$(dpkg-deb -f "$LATEST_DEB" Section 2>/dev/null || true)"

PACKAGE="${PACKAGE:-unknown-package}"
NAME="${NAME:-$PACKAGE}"
VERSION="${VERSION:-0.0.0}"
DESCRIPTION="${DESCRIPTION:-No description}"
AUTHOR="${AUTHOR:-moco}"
SECTION="${SECTION:-Tweaks}"

PACKAGE="$PACKAGE" \
NAME="$NAME" \
VERSION="$VERSION" \
DESCRIPTION="$DESCRIPTION" \
AUTHOR="$AUTHOR" \
SECTION="$SECTION" \
JSON_OUT="$JSON_OUT" \
BASE_URL="$BASE_URL" \
python3 <<'PY'
import os
import json

base_url = os.environ["BASE_URL"]

data = {
    "minVersion": "0.4",
    "class": "DepictionTabView",
    "headerImage": f"{base_url}/images/banner.png",
    "tintColor": "#6ec6d9",
    "backgroundColor": "#111111",
    "tabs": [
        {
            "tabname": "詳細",
            "class": "DepictionStackView",
            "views": [
                {
                    "class": "DepictionMarkdownView",
                    "markdown": os.environ["DESCRIPTION"]
                },
                {
                    "class": "DepictionSpacerView",
                    "spacing": 8
                },
                {
                    "class": "DepictionScreenshotsView",
                    "itemCornerRadius": 18,
                    "itemSize": "{140, 260}",
                    "screenshots": [
                        {
                            "url": f"{base_url}/images/ss1.png",
                            "accessibilityText": "Menu screenshot 1"
                        },
                        {
                            "url": f"{base_url}/images/ss2.png",
                            "accessibilityText": "Menu screenshot 2"
                        },
                        {
                            "url": f"{base_url}/images/ss3.png",
                            "accessibilityText": "Menu screenshot 3"
                        },
                        {
                            "url": f"{base_url}/images/ss4.png",
                            "accessibilityText": "Menu screenshot 4"
                        },
                        {
                            "url": f"{base_url}/images/ss5.png",
                            "accessibilityText": "Menu screenshot 5"
                        }
                    ]
                },
                {
                    "class": "DepictionSpacerView",
                    "spacing": 8
                },
                {
                    "class": "DepictionMarkdownView",
                    "markdown": (
                        f"### パッケージ情報\n"
                        f"- **Package**: {os.environ['PACKAGE']}\n"
                        f"- **Version**: {os.environ['VERSION']}\n"
                        f"- **Author**: {os.environ['AUTHOR']}\n"
                        f"- **Section**: {os.environ['SECTION']}"
                    )
                }
            ]
        }
    ]
}

with open(os.environ["JSON_OUT"], "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

(
  cd "$REPO_DIR"
  dpkg-scanpackages -m debs > Packages
  gzip -kf Packages
  sed -i '' 's/^Sileodepiction:/SileoDepiction:/g' Packages
  gzip -kf Packages
)

git add .

if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m "repo update: $PACKAGE $VERSION"
  git push
fi

echo "Repo updated!"